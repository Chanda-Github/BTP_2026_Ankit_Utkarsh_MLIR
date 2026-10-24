# Track B: MLIR-driven RISC-V instruction-set minimization + CPOG

Goal (supervisor comments 9, 13, 14): compile the Tsetlin Machine workload through real MLIR
to RISC-V, find the subset of RV32I it actually needs, then use CPOG (following Mokhov et al.,
"Design of Processors with Reconfigurable Microarchitecture", JLPEA 2014, the Intel 8051 flow)
to synthesize a minimal controller with maximum datapath reuse, and compare PPA against
the lab's UltraEmbedded R1 (full RV32IM) and R2 (reduced) cores from the ISVLSI'26 work.

## Steps

| # | Step | Status |
|---|---|---|
| 1 | TM model → MLIR (`func`/`arith`) → LLVM IR → RV32I ELF | done |
| 2 | Run on Spike (`--isa=rv32i`), golden check, static + dynamic ISA profile | done |
| 2b | **Core flow:** MLIR T1/T2 loop kernels → `memoryi.mem`/`memoryd.mem` for the lab's R1/R2 cores, replacing the manual extract-and-edit step; verified on Spike and on the R1/R2 Verilog (see `core_flow/README.md`) | done |
| 3 | Datapath units + partial order (PO) per instruction for the R1/R2 (UltraEmbedded) core; group into PO classes | next |
| 4 | Compose CPOGs (full RV32I vs workload subset); encode classes; synthesize controller (Workcraft) | |
| 5 | PPA: instruction level (controller/decoder) and core level (Vivado, against R1/R2) | |
| 6 | MLIR passes that change the instruction mix (Track A, clause-level sharing) and re-profile | |

## Run

```bash
./setup_tools.sh                                   # once
export PATH=/usr/lib/llvm-18/bin:/opt/spike/bin:$PATH
./run_track_b.sh                                   # all models in models/
cat out/iris/isa_profile.md
```

## Real trained models (CoDALab BTP25_RISCVTsetlinMachine)

The 2025 lab project "Energy Efficient Tsetlin Machine Inference on Single Core RISC-V Processor"
stored its trained models only inside RISC-V data-memory images (`Tests/<dataset>/<clauses>/memoryd.mem`).
`import_codalab.py` decodes all 50 of them (8 datasets, 2–19 classes, 12–560 features, 4–500
clauses per class) and validates each one three ways:

1. Test accuracy on the real test set matches the project's reported figures (e.g. Iris/4 = 96.67%).
2. The input sample stored in each memory image is a real test row, which confirms the literal order.
3. The prediction on that stored sample equals their RTL simulation result (`expected_output.txt`).

```bash
./run_codalab.sh ~/path/to/BTP25_RISCVTsetlinMachine-main       # all 50 models (~30 min)
./run_codalab.sh ~/path/to/BTP25_RISCVTsetlinMachine-main iris/4 sports/300   # selected ones
cat out/codalab/SUMMARY.md
```

The models stay out of git (`models/codalab/`, `out/codalab/`) because they are the lab's data.
Only the metrics summary is committed.

## Files

- `emit_mlir.py`: `tm_model.json` → `workload.mlir` and `golden.h`. Golden outputs come straight from the include masks, independent of MLIR.
- `build.sh`: `mlir-opt` (arith/func → llvm) → `mlir-translate` → `llc -mtriple=riscv32` → link with the bare-metal harness.
- `harness/`: startup code, test loop and linker script for Spike (no libc, no CSR instructions).
- `import_codalab.py`, `run_codalab.sh`, `summarize_codalab.py`: import, compile and profile the CoDALab trained models.
- `profile_isa.py`: static usage (all code paths, safe basis for removal) and dynamic counts (weights only); kernel vs harness reported separately.

Instruction removal uses the **static** profile only. It covers every path through the compiled
code, so unseen input data cannot reach a removed instruction. This follows supervisor
comments 10 and 11: no pruning based on observed data.
