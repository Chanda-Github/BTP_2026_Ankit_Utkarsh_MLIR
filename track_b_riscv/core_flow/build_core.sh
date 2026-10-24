#!/usr/bin/env bash
# build_core.sh <dir>     (dir produced by gen_loop_tm.py)
#
#  kernel.mlir --mlir-opt--> LLVM dialect --mlir-translate--> kernel.ll
#  entry_*.c   --clang----> entry_*.ll
#  llvm-link + opt -Os (everything inlined into one entry, no unrolling: IMEM is 256 words;
#                      no loop-idiom memset/memcpy calls)
#  llc -disable-lsr: loop-strength-reduction would re-create multiplies (RV32I has no mul)
#  llc (rv32i)  -> core_r1.s         R1: full RV32IM core
#  llc (rv32i, x31 reserved) -> rewrite_r2.py -> core_r2.s   R2: reduced core
#  link (IMEM/DMEM at 0) -> make_mem.py -> <dir>/r1/memory{i,d}.mem, <dir>/r2/memory{i,d}.mem
#  The same R1 and R2 code is also linked with a Spike harness and checked on real test samples.
set -euo pipefail
D=${1:?usage: build_core.sh <dir>}
HERE=$(cd "$(dirname "$0")" && pwd)
LLVM=${LLVM_BIN:-/usr/lib/llvm-18/bin}
SPIKE=${SPIKE:-/opt/spike/bin/spike}
T=riscv32-unknown-elf
CF="--target=$T -march=rv32i -mabi=ilp32 -mno-relax -nostdlib"
CC_ONLY="-ffreestanding -fno-builtin"

# 1. MLIR -> LLVM IR
"$LLVM/mlir-opt" "$D/kernel.mlir" --convert-scf-to-cf \
    --finalize-memref-to-llvm="index-bitwidth=32" --convert-arith-to-llvm="index-bitwidth=32" \
    --convert-cf-to-llvm="index-bitwidth=32" \
    --convert-func-to-llvm="index-bitwidth=32 use-bare-ptr-memref-call-conv=1" \
    --reconcile-unrealized-casts -o "$D/kernel.llvm.mlir"
"$LLVM/mlir-translate" --mlir-to-llvmir "$D/kernel.llvm.mlir" -o "$D/kernel.ll"

# 2. one optimised module per program (core image / Spike harness)
for prog in core spike; do
    entry=tm_entry; [ $prog = spike ] && entry=main
    "$LLVM/clang" $CF $CC_ONLY -O2 -S -emit-llvm "$D/entry_$prog.c" -o "$D/entry_$prog.ll"
    "$LLVM/llvm-link" "$D/kernel.ll" "$D/entry_$prog.ll" -o "$D/$prog.bc" 2>/dev/null
    "$LLVM/opt" -mtriple=$T -passes="internalize,default<Os>" -internalize-public-api-list=$entry \
        -disable-loop-idiom-all -unroll-threshold=0 -unroll-full-max-count=0 \
        "$D/$prog.bc" -o "$D/$prog.opt.bc"
done

# 3. code generation for R1 and R2, link, memory images, Spike check
"$LLVM/clang" $CF -c "$HERE/crt0_core.S" -o "$D/crt0_core.o"
"$LLVM/clang" $CF -c "$HERE/../harness/crt0.S" -o "$D/crt0_spike.o"
( cd "$D" && "$LLVM/clang" $CF -c data.S -o data.o )
for core in r1 r2; do
    MATTR=""; [ $core = r2 ] && MATTR="+reserve-x31"
    for prog in core spike; do
        "$LLVM/llc" -O2 -mtriple=$T -mattr="$MATTR" --riscv-no-aliases -disable-lsr "$D/$prog.opt.bc" -o "$D/${prog}_$core.raw.s"
        if [ $core = r2 ]; then
            python3 "$HERE/rewrite_r2.py" "$D/${prog}_$core.raw.s" "$D/${prog}_$core.s" $([ $prog = spike ] && echo --harness) > "$D/${prog}_r2.rewrite.log"
        else
            cp "$D/${prog}_$core.raw.s" "$D/${prog}_$core.s"
        fi
        "$LLVM/clang" $CF -c "$D/${prog}_$core.s" -o "$D/${prog}_$core.o"
    done
    "$LLVM/ld.lld" --no-check-sections -T "$HERE/link_core.ld" \
        "$D/crt0_core.o" "$D/core_$core.o" "$D/data.o" -o "$D/core_$core.elf"
    python3 "$HERE/make_mem.py" "$D/core_$core.elf" "$D/$core" $core "$LLVM"
    [ $core = r2 ] && sed "s/^/       /" "$D/core_r2.rewrite.log"

    "$LLVM/ld.lld" -T "$HERE/../harness/link.ld" "$D/crt0_spike.o" "$D/spike_$core.o" "$D/data.o" \
        -o "$D/spike_$core.elf"
    if "$SPIKE" --isa=rv32i -m0x80000000:0x4000000 "$D/spike_$core.elf"; then
        echo "[spike] $core code: all $(python3 -c "import json;print(json.load(open('$D/expected.json'))['spike_vectors'])") test samples match the golden model"
    else
        echo "[spike] $core code: FAILED ($? mismatching samples)"; exit 1
    fi
done
