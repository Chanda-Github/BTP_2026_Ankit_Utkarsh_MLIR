#!/usr/bin/env bash
# run_core_flow.sh <model.json> <t1|t2> <out_dir> [codalab_repo_root]
#   One command from a trained TM to verified memory files for the lab's RISC-V cores:
#     1. MLIR kernel + data memory          (gen_loop_tm.py)
#     2. compile for R1 and R2, check ISA, write memoryi.mem / memoryd.mem, verify on Spike
#                                           (build_core.sh)
#     3. optional: run both images on the R1/R2 Verilog with Icarus (sim_rtl.sh)
#   Output: <out_dir>/r1/memory{i,d}.mem and <out_dir>/r2/memory{i,d}.mem, ready for Vivado.
#   Env: SAMPLE=<test sample index for the core image> (default 0)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
MODEL=${1:?usage: run_core_flow.sh <model.json> <t1|t2> <out_dir> [codalab_repo_root]}
VAR=${2:?}
OUT=${3:?}
ROOT=${4:-}
python3 "$HERE/gen_loop_tm.py" "$MODEL" "$VAR" "$OUT" --sample "${SAMPLE:-0}"
"$HERE/build_core.sh" "$OUT" 2>&1 | grep -v "^clang: warning"
if [ -n "$ROOT" ]; then
    for c in r1 r2; do "$HERE/sim_rtl.sh" "$ROOT" $c "$OUT/$c"; done
fi
