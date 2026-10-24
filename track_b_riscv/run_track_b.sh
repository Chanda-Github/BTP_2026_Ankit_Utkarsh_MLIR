#!/usr/bin/env bash
# run_track_b.sh [march]   -- steps 1-2 of Track B for every model in models/
#   1. TM model -> MLIR (func/arith) -> RV32I ELF          (emit_mlir.py, build.sh)
#   2. Run on Spike restricted to the chosen ISA, check all input vectors against golden,
#      and profile which RV32I instructions are used (static + dynamic)   (profile_isa.py)
set -euo pipefail
cd "$(dirname "$0")"
MARCH=${1:-rv32i}
SPIKE=${SPIKE:-/opt/spike/bin/spike}

for model in models/*.json; do
    w=out/$(basename "$model" .json)
    python3 emit_mlir.py "$model" "$w"
    ./build.sh "$w" "$MARCH"
    if "$SPIKE" --isa="$MARCH" -m0x80000000:0x200000 -l --log="$w/spike.log" "$w/tm.elf"; then
        echo "[spike] $w: all input vectors match golden outputs"
    else
        echo "[spike] $w: FAILED (exit $?) -- mismatching vectors"; exit 1
    fi
    python3 profile_isa.py "$w" "$w/spike.log"
done
echo "Reports: out/*/isa_profile.md"
