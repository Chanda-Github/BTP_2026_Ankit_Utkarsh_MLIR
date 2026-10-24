# Track B: MLIR-driven RISC-V instruction-set minimization + CPOG

Goal (supervisor comments 9, 13, 14): compile the Tsetlin Machine workload through real MLIR
to RISC-V, find the subset of RV32I it actually needs, then use CPOG (following Mokhov et al.,
"Design of Processors with Reconfigurable Microarchitecture", JLPEA 2014, the Intel 8051 flow)
to synthesize a minimal controller with maximum datapath reuse, and compare PPA against an
Ibex (formerly Zero-riscy) baseline.

## Steps

| # | Step | Status |
|---|---|---|
| 1 | TM model → MLIR (`func`/`arith`) → LLVM IR → RV32I ELF | done |
| 2 | Run on Spike (`--isa=rv32i`), golden check, static + dynamic ISA profile | done |
| 3 | Datapath units + partial order (PO) per instruction for an Ibex-style RV32I core; group into PO classes | next |
| 4 | Compose CPOGs (full RV32I vs workload subset); encode classes; synthesize controller (Workcraft) | |
| 5 | PPA: instruction level (controller/decoder) and core level (Yosys + OpenSTA, Ibex configs) | |
| 6 | MLIR passes that change the instruction mix (Track A, clause-level sharing) and re-profile | |

## Run

```bash
./setup_tools.sh                                   # once
export PATH=/usr/lib/llvm-18/bin:/opt/spike/bin:$PATH
./run_track_b.sh                                   # all models in models/
cat out/iris/isa_profile.md
```

## Files

- `emit_mlir.py`: `tm_model.json` → `workload.mlir` and `golden.h`. Golden outputs come straight from the include masks, independent of MLIR.
- `build.sh`: `mlir-opt` (arith/func → llvm) → `mlir-translate` → `llc -mtriple=riscv32` → link with the bare-metal harness.
- `harness/`: startup code, test loop and linker script for Spike (no libc, no CSR instructions).
- `profile_isa.py`: static usage (all code paths, safe basis for removal) and dynamic counts (weights only); kernel vs harness reported separately.

Instruction removal uses the **static** profile only. It covers every path through the compiled
code, so unseen input data cannot reach a removed instruction. This follows supervisor
comments 10 and 11: no pruning based on observed data.
