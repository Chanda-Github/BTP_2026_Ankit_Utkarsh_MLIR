# Core flow: trained TM → MLIR → `memoryi.mem` / `memoryd.mem` for the lab's R1/R2 cores

This flow automates the manual part of the ISVLSI'26 flow. That flow had six manual steps:

1. Cross-compile the C++ inference with gcc.
2. Cut `predict` out of the objdump.
3. Replace pseudo-instructions by hand.
4. Emulate the stack and type DMEM addresses into the assembly.
5. Paste the assembly into the online assembler.
6. Run `create_memory_*.cpp` and paste `memory.txt`.

Here, one command does all of it:

```bash
./run_core_flow.sh ../models/codalab/statlog_100.json t2 ../out/core/statlog_100_t2  [~/BTP25_RISCVTsetlinMachine-main]
```

| Manual step (paper) | Automated here |
|---|---|
| C++ `predict()` + gcc, cut out of objdump | `gen_loop_tm.py` writes the T1/T2 kernel in MLIR (`func`, `scf`, `memref`, `arith`) |
| Pseudo-instruction replacement | Not needed: pseudo-instructions only exist in assembly text. `llc --riscv-no-aliases` and the checker work on real instructions. |
| Instructions R2 lacks (`bge`, `sub`, `sltiu`, …) | `rewrite_r2.py`: exact rewrites using reserved register `x31`, verified on Spike. The paper's `bge x,y → blt y,x` is **not** exact when x = y. |
| Stack set-up, parameter addresses typed in | `crt0_core.S` + `link_core.ld`: the linker places every array, so no address is copied by hand |
| `create_memory_*.cpp`, `memory.txt` | `gen_loop_tm.py` writes `data.S` + binary blobs; `make_mem.py` writes `memoryd.mem` |
| Online assembler → `memoryi.mem` | `make_mem.py` (`llvm-objcopy`), plus a check that every instruction is decoded by R1/R2 and the program fits the 256-word IMEM |

## What `build_core.sh` does

1. `mlir-opt`: lower `scf`/`memref`/`arith` to the LLVM dialect with a 32-bit `index`. `mlir-translate` then produces LLVM IR.
2. Link with the entry routine and run `opt -Os` with these options:
   - **Kernel inlined:** R2 has no `jalr`, so there is no call or return.
   - **No loop unrolling:** IMEM is 256 words; programs come out at about 90–100 words for every model size.
   - **No `memset`/`memcpy` calls** generated.
3. `llc -march rv32i`, with `-disable-lsr`: loop strength reduction would re-create multiplies, and RV32I has none. For R2, also `+reserve-x31` and then `rewrite_r2.py`.
4. Link for the core (IMEM and DMEM both at 0), then `make_mem.py` writes the two `.mem` files and checks the ISA.
5. Link the **same compiled code** with a Spike harness and check it against the golden model on real test samples, for both R1 and R2 code.

`sim_rtl.sh` then runs the generated `.mem` files on the lab's own Verilog (`new-RISCV/rv32im_2_meminc` = R1, `rv32im_2_mod3_2` = R2) with Icarus Verilog.

## Using the files in Vivado

Copy `r1/memoryi.mem` + `r1/memoryd.mem` (or the `r2/` pair) to where `tcm_mem_ram.v` reads them,
as before. The predicted class is at **DMEM address 0** (`Addr 0x00000000` in the report).

**End of program.** The generated programs store the class to DMEM[0], then jump to an `ecall`
at the very end of the program, behind 4 `nop`s so the core's 2–3-word prefetch can never reach
it early. The lab testbench used for the ISVLSI'26 runs ends the simulation when it fetches an
`ecall`, so **it works unchanged**: it prints PROGRAM EXECUTION COMPLETED / Total Clock Cycles /
Total Instructions / Execution Time / INSTRUCTION PROFILE / INSTRUCTION MIX, measured the same way
as the paper's programs. Set `CLK_PERIOD` to 14 (R1) or 12 (R2) and comment out `$dumpvars`.

The repo's older testbench (end detection by "PC stable for 100 cycles") never finishes with
this core. `vivado/riscv_tcm_top_tb_R1.v` / `_R2.v` add a report block that stops at the result
store and also prints a retired-instruction profile.

## Results so far (R1/R2 Verilog, Icarus Verilog)

Same model, same input sample, same core. Cycles run from reset release to the final result
store. For the paper's programs, the cycle shown is the last DMEM[0] store before the program
restarts.

| Model / program | Paper flow (gcc, hand-edited) | MLIR core flow | Ratio |
|---|---:|---:|---:|
| iris/4, T1, R1 | 20,714 | 3,916 | 5.3× |
| iris/4, T2, R1 | 3,319 | 756 | 4.4× |
| statlog/100, T2, R1 (test row 3) | 418,380 | 70,646 | 5.9× |

R2 runs of the generated programs (all correct): iris/4 T1 3,928, T2 787; statlog/100 T2
(row 0) 40,945 cycles. Most of the gap comes from compiler optimization: the paper's code was
compiled without optimization, so variables live on the stack. The flow gets optimized code
automatically, with no hand edits and with exact R2 rewrites.

Program size: 90–100 instruction words for every model tested (iris, mammography, statlog,
EMG, sports, HAR, gesture; up to 19 classes and 500 clauses per class). The paper's programs
are about 200 words.

## Checking against the paper's own memory files

`compare_with_paper.py` runs the paper's `Tests/` memory files and the MLIR-generated ones on the
same R1/R2 Verilog, for the same model and the same input sample, then reads votes[] and the
predicted class back out of data memory:

```bash
python3 core_flow/compare_with_paper.py ~/path/to/BTP25_RISCVTsetlinMachine-main       # 6 cases, ~6 min
python3 core_flow/compare_with_paper.py <root> iris/4/t1 statlog/100/t2 --cores r1    # chosen cases
cat out/compare/REPORT.md
```

Result of the default set (both cores):
- The predicted class is the same for the paper image, the MLIR image and the golden model in every case.
- The MLIR images' votes equal the golden model's in every case.
- The paper images' votes equal the golden model's for mammography. For iris, statlog and HAR
  they differ by +2 in the classes where clause C/2 fires, exactly as the `bge x,y -> blt y,x`
  rewrite predicts. The class still comes out right in these cases because the margin is
  larger than 2.
- Paper programs take the same cycles on R1 and R2 (identical code); the MLIR programs take
  4.7-6.0x fewer cycles.

## Execution time vs #clauses (the paper's Fig. 5)

`exec_time_sweep.py` measures cycles on the R1/R2 Verilog for every dataset × clauses × T1/T2 ×
core, for both the MLIR images and the paper's own `Tests/` images. It uses the same model and
the same input sample for both, and converts cycles to time with the paper's clock periods
(R1 14 ns, R2 12 ns), the same way the Vivado testbench prints Execution Time.

```bash
python3 core_flow/exec_time_sweep.py ~/path/to/BTP25_RISCVTsetlinMachine-main          # ~30-40 min
python3 core_flow/exec_time_sweep.py <root> --datasets statlog --clauses 50,100         # quick
python3 core_flow/exec_time_sweep.py <root> --no-paper                                  # MLIR only
```

Outputs go to `out/exectime/`: `fig5_exec_time.png` / `.pdf`, `TABLE.md` and `results.csv`.

Every run reads the class and all class votes back from data memory and checks them:
- all 96 MLIR runs equal the golden model;
- 40 paper runs equal the golden model, and the other 56 equal exactly the `bge`-swap semantics.

Result for Statlog, Gesture, Gas and EMG, 50–300 clauses:
- The paper images reproduce the paper's Fig. 5 values (T1 10²–10³ ms, T2 2–15 ms).
- The MLIR images are 5.1–5.6× faster for T1 and 4.8–6.0× faster for T2.

**Simulator.** `sim_rtl.sh` uses Verilator when installed: about 1.3M cycles/s, against about 4.5k
cycles/s for Icarus. Each core is built once and cached. Cycle counts are identical to Icarus.

Note: 198 of the paper's 200 memory files have no newline after the last word. Verilator's
`$readmemh` then reads that word as 0, which breaks T1 images (their last word is a
`clause_output` pointer). `sim_rtl.sh` adds the missing newline before each run. Vivado and
Icarus read these files correctly.

## Files

| File | Role |
|---|---|
| `gen_loop_tm.py` | Writes the MLIR kernel (T1 or T2), the data memory (`data.S` + blobs), the core entry, the Spike harness and `expected.json` |
| `build_core.sh` | Compiles for R1 and R2, writes the memory files, checks the ISA, verifies on Spike |
| `rewrite_r2.py` | Exact rewrites for instructions R2's decoder does not accept |
| `make_mem.py` | ELF → `memoryi.mem` / `memoryd.mem`; ISA and IMEM-size check |
| `crt0_core.S`, `link_core.ld` | Start-up and memory map of the TCM core |
| `sim_rtl.sh` | Runs a pair of memory files on the R1/R2 Verilog (Icarus) |
| `run_core_flow.sh` | All of the above in one command |
| `exec_time_sweep.py` | Fig. 5: execution time vs #clauses, MLIR vs paper images, all results checked |
| `iss_harvard.py` | Tiny RV32I instruction-set simulator with separate IMEM/DMEM (separates program bugs from core bugs) |
| `compare_with_paper.py` | Same model/sample/core: paper `Tests/` images vs MLIR images vs golden, votes included |
