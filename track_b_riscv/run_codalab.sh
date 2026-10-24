#!/usr/bin/env bash
# run_codalab.sh <codalab_repo_root> [dataset/clauses ...]
#   Import trained models from the CoDALab BTP25_RISCVTsetlinMachine repo, then for each:
#   MLIR -> RV32I -> Spike (real test samples vs golden) -> ISA profile.
#   Model files and outputs stay out of git (models/codalab/, out/codalab/): the trained
#   models are the lab's data, regenerate them from your own copy of that repo.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=${1:?usage: run_codalab.sh <codalab_repo_root> [dataset/clauses ...]}
shift
SPIKE=${SPIKE:-/opt/spike/bin/spike}

python3 import_codalab.py "$ROOT" models/codalab "$@"
for model in models/codalab/*.json; do
    name=$(basename "$model" .json)
    [ "$name" = codalab_summary ] && continue
    w=out/codalab/$name
    python3 emit_mlir.py "$model" "$w" > /dev/null
    ./build.sh "$w" rv32i > /dev/null
    if "$SPIKE" --isa=rv32i -m0x80000000:0x800000 -l --log="$w/spike.log" "$w/tm.elf"; then
        python3 profile_isa.py "$w" "$w/spike.log"
    else
        echo "[spike] $w: FAILED (mismatching test vectors)"; exit 1
    fi
    rm -f "$w/spike.log"   # traces are large; the profile keeps the counts
done
python3 summarize_codalab.py out/codalab models/codalab/codalab_summary.json
