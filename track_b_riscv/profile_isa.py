#!/usr/bin/env python3
"""
profile_isa.py  (Track B, step 2)
=================================
Which RV32I instructions does the MLIR-compiled TM workload actually need?

Two measurements, kept separate on purpose:
  * STATIC  -- every instruction present in the compiled code (objdump, no aliases).
               This is the safe basis for removing instructions: it covers every path,
               so unseen input data can never reach an instruction we dropped
               (supervisor comment 10/11: no pruning based on observed data).
  * DYNAMIC -- execution counts from a Spike commit trace over all input vectors.
               Used only for weighting (e.g. Huffman opcode encoding, as in the
               Mokhov et al. 2014 8051 flow), never for removal.

Kernel (tm_infer) and harness instructions are reported separately.

Usage:
    python3 profile_isa.py <workload_dir> [spike_trace.log]
Writes <workload_dir>/isa_profile.json and isa_profile.md
"""
import json
import re
import sys
from collections import Counter, OrderedDict

# The 40 RV32I base instructions (unprivileged spec), grouped by format/function.
RV32I = OrderedDict([
    ("U-type",      ["lui", "auipc"]),
    ("Jump",        ["jal", "jalr"]),
    ("Branch",      ["beq", "bne", "blt", "bge", "bltu", "bgeu"]),
    ("Load",        ["lb", "lh", "lw", "lbu", "lhu"]),
    ("Store",       ["sb", "sh", "sw"]),
    ("ALU-imm",     ["addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli", "srai"]),
    ("ALU-reg",     ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]),
    ("System",      ["fence", "ecall", "ebreak"]),
])
ALL_RV32I = [i for g in RV32I.values() for i in g]
assert len(ALL_RV32I) == 40
RV32M = ["mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"]

FUNC_RE = re.compile(r"^([0-9a-f]+) <([^>]+)>:")
INSN_RE = re.compile(r"^\s*([0-9a-f]+):\s+([a-z][a-z0-9.]*)")
SPIKE_RE = re.compile(r"core\s+\d+:\s+(?:\d\s+)?0x([0-9a-f]+)\s+\(0x[0-9a-f]+\)")


def parse_objdump(path):
    """Returns {addr: (function, mnemonic)} for every instruction in the ELF."""
    insns, func = {}, None
    for line in open(path):
        m = FUNC_RE.match(line)
        if m:
            func = m.group(2)
            continue
        m = INSN_RE.match(line)
        if m and func:
            insns[int(m.group(1), 16)] = (func, m.group(2))
    return insns


def parse_spike_trace(path, insns):
    """Counts executed instructions by address; ignores Spike's boot ROM (< 0x80000000)."""
    counts = Counter()
    for line in open(path, errors="replace"):
        m = SPIKE_RE.search(line)
        if m:
            a = int(m.group(1), 16)
            if a in insns:
                counts[a] += 1
    return counts


def summarize(insn_map, dyn_counts):
    static = {"kernel": Counter(), "harness": Counter()}
    dynamic = {"kernel": Counter(), "harness": Counter()}
    for addr, (func, mn) in insn_map.items():
        part = "kernel" if func == "tm_infer" else "harness"
        static[part][mn] += 1
        if dyn_counts:
            dynamic[part][mn] += dyn_counts.get(addr, 0)
    return static, dynamic


def write_reports(wdir, static, dynamic, have_dyn):
    k_used = set(static["kernel"])
    all_used = k_used | set(static["harness"])
    outside = sorted(m for m in all_used if m not in ALL_RV32I)
    report = {
        "rv32i_total": 40,
        "kernel_static": dict(static["kernel"]),
        "harness_static": dict(static["harness"]),
        "kernel_dynamic": dict(dynamic["kernel"]) if have_dyn else None,
        "harness_dynamic": dict(dynamic["harness"]) if have_dyn else None,
        "kernel_distinct": sorted(k_used),
        "program_distinct": sorted(all_used),
        "unused_rv32i": [i for i in ALL_RV32I if i not in all_used],
        "outside_rv32i": outside,
        "rv32m_used": sorted(set(RV32M) & all_used),
    }
    with open(f"{wdir}/isa_profile.json", "w") as f:
        json.dump(report, f, indent=2)

    L = [f"# RV32I usage profile: `{wdir}`", ""]
    L.append(f"- Kernel (`tm_infer`) uses **{len(k_used)} / 40** RV32I instructions")
    L.append(f"- Whole program (kernel + harness + startup) uses **{len(all_used)} / 40**")
    L.append(f"- RV32M (mul/div) instructions used: **{report['rv32m_used'] or 'none'}**")
    L.append(f"- Instructions outside RV32I: **{outside or 'none'}**")
    L.append("")
    L.append("| Group | Instruction | Kernel static | Kernel dynamic | Harness static | Harness dynamic |")
    L.append("|---|---|---:|---:|---:|---:|")
    for g, lst in RV32I.items():
        for i in lst:
            ks, hs = static["kernel"].get(i, 0), static["harness"].get(i, 0)
            kd = dynamic["kernel"].get(i, 0) if have_dyn else "-"
            hd = dynamic["harness"].get(i, 0) if have_dyn else "-"
            if ks or hs:
                L.append(f"| {g} | `{i}` | {ks} | {kd} | {hs} | {hd} |")
    L.append("")
    L.append("Unused RV32I instructions (candidates for removal, safe because the static "
             "analysis covers all paths): " + ", ".join(f"`{i}`" for i in report["unused_rv32i"]))
    with open(f"{wdir}/isa_profile.md", "w") as f:
        f.write("\n".join(L) + "\n")
    return report


def main():
    wdir = sys.argv[1]
    trace = sys.argv[2] if len(sys.argv) > 2 else None
    insn_map = parse_objdump(f"{wdir}/tm.dis")
    dyn = parse_spike_trace(trace, insn_map) if trace else None
    static, dynamic = summarize(insn_map, dyn)
    r = write_reports(wdir, static, dynamic, bool(dyn))
    print(f"[profile] {wdir}: kernel {len(r['kernel_distinct'])}/40, "
          f"program {len(r['program_distinct'])}/40, RV32M used: {r['rv32m_used'] or 'none'}")


if __name__ == "__main__":
    main()
