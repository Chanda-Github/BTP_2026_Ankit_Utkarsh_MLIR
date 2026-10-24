#!/usr/bin/env bash
# build.sh <workload_dir> [march]
#   MLIR (func/arith) -> LLVM dialect -> LLVM IR -> RV32 object (llc) -> linked ELF for Spike.
#   march defaults to rv32i (the 40-instruction base ISA, no M/A/C/F/D, no Zicsr).
set -euo pipefail

W=${1:?usage: build.sh <workload_dir> [march]}
MARCH=${2:-rv32i}
HERE=$(cd "$(dirname "$0")" && pwd)
LLVM_BIN=${LLVM_BIN:-/usr/lib/llvm-18/bin}

# llc -mattr string for the chosen -march (base I only by default)
case "$MARCH" in
  rv32i)  MATTR="" ;;
  rv32im) MATTR="+m" ;;
  rv32e)  MATTR="+e" ;;
  *) echo "unsupported march $MARCH"; exit 1 ;;
esac
ABI=ilp32; [ "$MARCH" = rv32e ] && ABI=ilp32e

# 1. Verify + lower MLIR to the LLVM dialect.
#    index-bitwidth=32: RV32 has 32-bit addresses; 64-bit index maths would be emulated with
#    extra sltu/add carry sequences and distort the instruction profile.
#    use-bare-ptr-memref-call-conv: a static memref<Nxi8> argument becomes a plain C pointer.
"$LLVM_BIN/mlir-opt" "$W/workload.mlir" \
    --finalize-memref-to-llvm="index-bitwidth=32" \
    --convert-arith-to-llvm="index-bitwidth=32" \
    --convert-func-to-llvm="index-bitwidth=32 use-bare-ptr-memref-call-conv=1" \
    --reconcile-unrealized-casts \
    -o "$W/workload.llvm.mlir"

# 2. LLVM dialect -> LLVM IR
"$LLVM_BIN/mlir-translate" --mlir-to-llvmir "$W/workload.llvm.mlir" -o "$W/workload.ll"

# 3. LLVM IR -> RV32 assembly + object (this is where instruction selection happens)
"$LLVM_BIN/llc" -O2 -mtriple=riscv32-unknown-elf -mattr="$MATTR" -target-abi=$ABI \
    "$W/workload.ll" -o "$W/workload.s"
"$LLVM_BIN/llc" -O2 -mtriple=riscv32-unknown-elf -mattr="$MATTR" -target-abi=$ABI \
    -filetype=obj "$W/workload.ll" -o "$W/workload.o"

# 4. Harness (same ISA restriction) + link
CFLAGS="--target=riscv32-unknown-elf -march=$MARCH -mabi=$ABI -O2 -ffreestanding -nostdlib -fno-builtin -I$W"
"$LLVM_BIN/clang" $CFLAGS -c "$HERE/harness/crt0.S" -o "$W/crt0.o"
"$LLVM_BIN/clang" $CFLAGS -c "$HERE/harness/main.c" -o "$W/main.o"
"$LLVM_BIN/ld.lld" -T "$HERE/harness/link.ld" "$W/crt0.o" "$W/main.o" "$W/workload.o" -o "$W/tm.elf"

# 5. Disassembly with real (non-pseudo) mnemonics, for static ISA profiling
"$LLVM_BIN/llvm-objdump" -d -M no-aliases --no-show-raw-insn "$W/tm.elf" > "$W/tm.dis"
echo "[build] $W/tm.elf  (march=$MARCH)"
