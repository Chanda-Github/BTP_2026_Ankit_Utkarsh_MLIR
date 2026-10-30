#!/usr/bin/env python3
"""
gen_loop_tm.py  --  MLIR loop kernels (T1 / T2 of the ISVLSI'26 paper) + data-memory contents
=============================================================================================
Replaces three manual steps of the paper's flow:
  * C++ predict() -> gcc -> cut predict out of objdump        => kernel written in MLIR (scf/memref/arith)
  * create_memory_standard/optimized.cpp + hand-copied addresses => data.S (the linker places it)
  * stack emulation / argument set-up in the edited assembly     => entry_core.c + linker script

Kernels (semantics identical to TM/standard.cpp and TM/optimized.cpp; clause data stays in memory,
so instruction-memory size does not grow with the model):
  T1  include[K][C][L] bytes + useful[K][C]; every literal of every useful clause is visited
  T2  only included literal indices (uint16), count[K][C] (uint16) + start[K][C]; early exit
      as soon as the clause output becomes 0 (the 'else break' of optimized.cpp)
  Both: clause_output[K][C] in memory, votes[i] = C +/- 1 per firing clause (j < C/2 positive),
        result = first class with the strictly largest vote (ties -> lowest index).

Usage:
    python3 gen_loop_tm.py <model.json> <t1|t2> <out_dir> [--sample N] [--spike-vectors M]
      model.json : tm_multiclass_v1 (from import_codalab.py)
      --sample N : test sample placed in DMEM for the core run (default 0, as in the paper)
      --spike-vectors M : number of test samples the Spike harness checks (default 30)
"""
import argparse
import json
import os


# ---------------------------------------------------------------------------------------------
# Reference model (independent of the MLIR): bit-exact port of TM/standard.cpp predict()
# ---------------------------------------------------------------------------------------------
def reference_predict(model, x):
    F, C = model["num_features"], model["clauses_per_class"]
    lit = list(x) + [1 - v for v in x]
    best, best_v = 0, 0
    for c, clauses in enumerate(model["classes"]):
        v = C
        for j, inc in enumerate(clauses):
            if inc and all(lit[k] for k in inc):
                v += 1 if j < C // 2 else -1
        if v > best_v:
            best, best_v = c, v
    return best


# ---------------------------------------------------------------------------------------------
# MLIR
# ---------------------------------------------------------------------------------------------
def _common_header(K, C, L):
    return f"""    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %cK = arith.constant {K} : index
    %cC = arith.constant {C} : index
    %cL = arith.constant {L} : index
    %cKC = arith.constant {K * C} : index
    %chalf = arith.constant {C // 2} : index
    %z8 = arith.constant 0 : i8
    %o8 = arith.constant 1 : i8
    %z32 = arith.constant 0 : i32
    %p1 = arith.constant 1 : i32
    %m1 = arith.constant -1 : i32
    %cC32 = arith.constant {C} : i32
"""


# Multiplication-free addressing: RV32I (and R2) has no multiplier, so the kernels never form
# (i*C + j)*L.  Clauses are visited in the same order as the C++ (class-major) through a flat
# clause counter q = i*C + j, and T1's include row offset advances by L per clause.

def _votes_and_argmax(K, C):
    return f"""
    // ---- Phase 2: class sums (Algorithm lines 9-16); q = i*C + j kept as a running counter ----
    %qend = scf.for %i = %c0 to %cK step %c1 iter_args(%qi = %c0) -> (index) {{
      memref.store %cC32, %votes[%i] : memref<{K}xi32>
      %qn = scf.for %j = %c0 to %cC step %c1 iter_args(%q = %qi) -> (index) {{
        %co = memref.load %clout[%q] : memref<{K * C}xi8>
        %fires = arith.cmpi ne, %co, %z8 : i8
        scf.if %fires {{
          %v = memref.load %votes[%i] : memref<{K}xi32>
          %pos = arith.cmpi ult, %j, %chalf : index
          %d = scf.if %pos -> (i32) {{
            scf.yield %p1 : i32
          }} else {{
            scf.yield %m1 : i32
          }}
          %nv = arith.addi %v, %d : i32
          memref.store %nv, %votes[%i] : memref<{K}xi32>
        }}
        %q1 = arith.addi %q, %c1 : index
        scf.yield %q1 : index
      }}
      scf.yield %qn : index
    }}

    // ---- Phase 3: argmax, first strictly larger vote wins (line 17) ----
    %res:2 = scf.for %i = %c0 to %cK step %c1 iter_args(%r = %z32, %m = %z32) -> (i32, i32) {{
      %v = memref.load %votes[%i] : memref<{K}xi32>
      %gt = arith.cmpi sgt, %v, %m : i32
      %ii = arith.index_cast %i : index to i32
      %nr = arith.select %gt, %ii, %r : i32
      %nm = arith.select %gt, %v, %m : i32
      scf.yield %nr, %nm : i32, i32
    }}
    return %res#0 : i32
  }}
}}
"""


def emit_t1(model):
    K, C, L = model["num_classes"], model["clauses_per_class"], 2 * model["num_features"]
    return f"""// T1 (vanilla) Tsetlin Machine inference -- paper Algorithm 1 / TM/standard.cpp
// {model['benchmark_name']}: {K} classes x {C} clauses, {L} literals. Dialects: func, scf, memref, arith.
// alwaysinline: R2 has no jalr, so the kernel is inlined into the entry routine (no call/return).
// Arrays are flat (clause q = i*C + j); offsets advance by addition, never by multiplication.
module {{
  func.func @tm_infer(%lit: memref<{L}xi8>, %inc: memref<{K * C * L}xi8>,
                      %useful: memref<{K * C}xi8>, %clout: memref<{K * C}xi8>,
                      %votes: memref<{K}xi32>) -> i32
      attributes {{passthrough = ["alwaysinline"]}} {{
{_common_header(K, C, L)}
    // ---- Phase 1: clause outputs (Algorithm lines 1-8), all K*C clauses in class-major order ----
    %rend = scf.for %q = %c0 to %cKC step %c1 iter_args(%row = %c0) -> (index) {{
      %u = memref.load %useful[%q] : memref<{K * C}xi8>
      %isu = arith.cmpi ne, %u, %z8 : i8
      scf.if %isu {{
        memref.store %o8, %clout[%q] : memref<{K * C}xi8>
        scf.for %k = %c0 to %cL step %c1 {{
          %co = memref.load %clout[%q] : memref<{K * C}xi8>
          %ik = arith.addi %row, %k : index
          %t = memref.load %inc[%ik] : memref<{K * C * L}xi8>
          %nt = arith.xori %t, %o8 : i8
          %l = memref.load %lit[%k] : memref<{L}xi8>
          %or = arith.ori %nt, %l : i8
          %a = arith.andi %co, %or : i8
          memref.store %a, %clout[%q] : memref<{K * C}xi8>
        }}
      }} else {{
        memref.store %z8, %clout[%q] : memref<{K * C}xi8>
      }}
      %row1 = arith.addi %row, %cL : index
      scf.yield %row1 : index
    }}
{_votes_and_argmax(K, C)}"""


def emit_t2(model, n_idx):
    K, C, L = model["num_classes"], model["clauses_per_class"], 2 * model["num_features"]
    N = max(1, n_idx)
    return f"""// T2 (modified, sparse) Tsetlin Machine inference -- paper Algorithm 2 / TM/optimized.cpp
// {model['benchmark_name']}: {K} classes x {C} clauses, {L} literals, {n_idx} stored literal indices.
// Dialects: func, scf, memref, arith.
// alwaysinline: R2 has no jalr, so the kernel is inlined into the entry routine (no call/return).
// Arrays are flat (clause q = i*C + j); no multiplication is needed for any address.
module {{
  func.func @tm_infer(%lit: memref<{L}xi8>, %count: memref<{K * C}xi16>,
                      %start: memref<{K * C}xi32>, %idx: memref<{N}xi16>,
                      %clout: memref<{K * C}xi8>, %votes: memref<{K}xi32>) -> i32
      attributes {{passthrough = ["alwaysinline"]}} {{
{_common_header(K, C, L)}
    // ---- Phase 1: clause outputs over included literals only (Algorithm lines 1-9) ----
    scf.for %q = %c0 to %cKC step %c1 {{
      %n16 = memref.load %count[%q] : memref<{K * C}xi16>
      %n = arith.extui %n16 : i16 to i32
      %has = arith.cmpi ne, %n, %z32 : i32
      scf.if %has {{
        memref.store %o8, %clout[%q] : memref<{K * C}xi8>
        %s = memref.load %start[%q] : memref<{K * C}xi32>
        // for k < count: if (clause_output) clause_output &= lit[offset[k]]; else break;
        %kend = scf.while (%k = %z32) : (i32) -> i32 {{
          %co = memref.load %clout[%q] : memref<{K * C}xi8>
          %inr = arith.cmpi ult, %k, %n : i32
          %alive = arith.cmpi ne, %co, %z8 : i8
          %go = arith.andi %inr, %alive : i1
          scf.condition(%go) %k : i32
        }} do {{
        ^bb0(%k: i32):
          %p = arith.addi %s, %k : i32
          %pi = arith.index_cast %p : i32 to index
          %off16 = memref.load %idx[%pi] : memref<{N}xi16>
          %off32 = arith.extui %off16 : i16 to i32
          %offi = arith.index_cast %off32 : i32 to index
          %l = memref.load %lit[%offi] : memref<{L}xi8>
          %co = memref.load %clout[%q] : memref<{K * C}xi8>
          %a = arith.andi %co, %l : i8
          memref.store %a, %clout[%q] : memref<{K * C}xi8>
          %k1 = arith.addi %k, %p1 : i32
          scf.yield %k1 : i32
        }}
      }} else {{
        memref.store %z8, %clout[%q] : memref<{K * C}xi8>
      }}
    }}
{_votes_and_argmax(K, C)}"""


# ---------------------------------------------------------------------------------------------
# Data memory (replaces create_memory_*.cpp): raw blobs + an assembly file that names them.
# The linker assigns every address, so nothing is copied by hand into the program.
# ---------------------------------------------------------------------------------------------
def write_data(model, variant, out, sample_bits):
    K, C, F = model["num_classes"], model["clauses_per_class"], model["num_features"]
    L = 2 * F
    blobs = []          # (symbol, filename, bytes, align)
    if variant == "t1":
        inc = bytearray(K * C * L)
        useful = bytearray(K * C)
        for i, cl in enumerate(model["classes"]):
            for j, lits in enumerate(cl):
                for k in lits:
                    inc[(i * C + j) * L + k] = 1
                useful[i * C + j] = 1 if lits else 0
        blobs += [("tm_inc", "inc.bin", bytes(inc), 0), ("tm_useful", "useful.bin", bytes(useful), 0)]
        n_idx = 0
    else:
        count = bytearray()
        start = bytearray()
        idx = bytearray()
        n = 0
        for cl in model["classes"]:
            for lits in cl:
                count += len(lits).to_bytes(2, "little")
                start += n.to_bytes(4, "little")
                for k in lits:
                    idx += k.to_bytes(2, "little")
                n += len(lits)
        if n == 0:
            idx += b"\0\0"
        blobs += [("tm_count", "count.bin", bytes(count), 1), ("tm_start", "start.bin", bytes(start), 2),
                  ("tm_idx", "idx.bin", bytes(idx), 1)]
        n_idx = n
    lit = bytes(sample_bits + [1 - b for b in sample_bits])

    S = ["# Data memory for the TM kernel -- generated by gen_loop_tm.py (replaces create_memory_*.cpp)",
         "    .section .rodata.tm_model, \"a\""]
    for sym, fn, data, align in blobs:
        with open(os.path.join(out, fn), "wb") as f:
            f.write(data)
        S += [f"    .p2align {max(align, 2)}", f"    .globl {sym}", f"{sym}:", f"    .incbin \"{fn}\"",
              f"    .size {sym}, {len(data)}"]
    S += ["    .data", "    .p2align 2", "    .globl tm_lit", "tm_lit:",
          "    .byte " + ",".join(map(str, lit)), f"    .size tm_lit, {L}",
          "    .bss", "    .p2align 2",
          "    .globl tm_votes", "tm_votes:", f"    .zero {4 * K}",
          "    .globl tm_clout", "tm_clout:", f"    .zero {K * C}"]
    with open(os.path.join(out, "data.S"), "w") as f:
        f.write("\n".join(S) + "\n")
    return n_idx


def write_entries(model, variant, out, test_rows, expected):
    K, C, F = model["num_classes"], model["clauses_per_class"], model["num_features"]
    L = 2 * F
    if variant == "t1":
        decl = ("extern const unsigned char tm_inc[], tm_useful[];",
                "tm_infer(tm_lit, tm_inc, tm_useful, tm_clout, tm_votes)",
                "int tm_infer(unsigned char *lit, const unsigned char *inc, const unsigned char *useful,\n"
                "             unsigned char *clout, int *votes);")
    else:
        decl = ("extern const unsigned short tm_count[], tm_idx[];\nextern const int tm_start[];",
                "tm_infer(tm_lit, tm_count, tm_start, tm_idx, tm_clout, tm_votes)",
                "int tm_infer(unsigned char *lit, const unsigned short *count, const int *start,\n"
                "             const unsigned short *idx, unsigned char *clout, int *votes);")
    common = (f"// generated by gen_loop_tm.py -- {model['benchmark_name']} {variant.upper()}\n"
              f"{decl[2]}  /* MLIR kernel */\n{decl[0]}\n"
              "extern unsigned char tm_lit[];\nextern unsigned char tm_clout[];\nextern int tm_votes[];\n")
    # Core entry: no call/return left after inlining (R2 has no jalr); result -> DMEM address 0, then
    # jump to tm_halt (crt0_core.S): ecall, which ends the run in the lab testbench.
    core = common + f"""
volatile int tm_result __attribute__((section(".result")));

__attribute__((noreturn)) void tm_entry(void) {{
    tm_result = {decl[1]};
    __asm__ volatile ("jal zero, tm_halt");   /* -> ecall: the lab testbench ends the run on it */
    __builtin_unreachable();
}}
"""
    with open(os.path.join(out, "entry_core.c"), "w") as f:
        f.write(core)
    # Spike entry: many real test samples, golden comparison, exit status = #mismatches.
    rows = ",\n".join("  {" + ",".join(map(str, r)) + "}" for r in test_rows)
    spike = common + f"""
#define NV {len(test_rows)}
#define F {F}
static const unsigned char tv_x[NV][F] = {{
{rows}
}};
static const unsigned char tv_expected[NV] = {{ {", ".join(map(str, expected))} }};

int main(void) {{
    int errors = 0;
    const unsigned char *x = &tv_x[0][0];          /* pointer walk: no v*F multiply */
    for (int v = 0; v < NV; v++, x += F) {{
        for (int k = 0; k < F; k++) {{ tm_lit[k] = x[k]; tm_lit[F + k] = 1 - x[k]; }}
        if ({decl[1]} != tv_expected[v]) errors++;
    }}
    return errors;
}}
"""
    with open(os.path.join(out, "entry_spike.c"), "w") as f:
        f.write(spike)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("variant", choices=["t1", "t2"])
    ap.add_argument("out")
    ap.add_argument("--sample", type=int, default=0)
    ap.add_argument("--spike-vectors", type=int, default=30)
    a = ap.parse_args()
    model = json.load(open(a.model))
    assert model.get("format") == "tm_multiclass_v1", "needs a multi-class model (import_codalab.py)"
    os.makedirs(a.out, exist_ok=True)

    rows = [[int(ch) for ch in r] for r in model["test_inputs"]]
    exp = [reference_predict(model, x) for x in rows]
    if "reference_predictions" in model:
        assert exp == model["reference_predictions"], "reference disagrees with importer"
    sample = rows[a.sample]

    n_idx = write_data(model, a.variant, a.out, sample)
    mlir = emit_t1(model) if a.variant == "t1" else emit_t2(model, n_idx)
    with open(os.path.join(a.out, "kernel.mlir"), "w") as f:
        f.write(mlir)
    nv = min(a.spike_vectors, len(rows))
    write_entries(model, a.variant, a.out, rows[:nv], exp[:nv])
    json.dump({"model": model["benchmark_name"], "variant": a.variant, "sample": a.sample,
               "expected_result": exp[a.sample], "spike_vectors": nv},
              open(os.path.join(a.out, "expected.json"), "w"), indent=2)
    print(f"[gen] {model['benchmark_name']} {a.variant.upper()}: kernel.mlir, data.S, entries "
          f"-> {a.out} (sample {a.sample} expects class {exp[a.sample]})")


if __name__ == "__main__":
    main()
