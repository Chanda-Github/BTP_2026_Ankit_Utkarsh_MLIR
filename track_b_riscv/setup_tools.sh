#!/usr/bin/env bash
# One-time tool setup for Track B on Ubuntu 22.04/24.04 (tested on 24.04).
# Installs: MLIR 18 + LLVM/clang/lld (compile MLIR -> RV32I), Spike (RISC-V ISA simulator),
# and the hardware tools used in later steps (Yosys, Verilator, Icarus Verilog).
set -euo pipefail

sudo apt-get update
sudo apt-get install -y mlir-18-tools llvm-18 clang-18 lld-18 \
    build-essential device-tree-compiler libboost-regex-dev libboost-system-dev \
    yosys verilator iverilog python3 git

# Spike: build from source with its softfloat submodule (the apt-free, reference simulator)
if [ ! -x /opt/spike/bin/spike ]; then
    rm -rf /tmp/spike-src
    git clone --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/riscv-software-src/riscv-isa-sim.git /tmp/spike-src
    mkdir -p /tmp/spike-src/build && cd /tmp/spike-src/build
    ../configure --prefix=/opt/spike
    make -j"$(nproc)"
    sudo make install
fi

echo
echo "Done. Add to your shell profile:"
echo '  export PATH=/usr/lib/llvm-18/bin:/opt/spike/bin:$PATH'
