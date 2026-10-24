#!/usr/bin/env python3
"""
make_mem.py <core.elf> <out_dir> <r1|r2> [llvm_bin]
===================================================
Writes the two files the UltraEmbedded testbench loads with $readmemh (tcm_mem_ram.v):
  memoryi.mem  -- IMEM words (instr_mem[255:0]), from .text
  memoryd.mem  -- DMEM words (data_mem[...]) from address 0 up to the end of .bss (zeros included,
                  so nothing the program reads is left as X); the stack lies above and is
                  written before it is read
and checks that every instruction is one the target core decodes.
Replaces: copying objdump output into the online assembler, and pasting memory.txt by hand.
"""
import os
import re
import subprocess
import sys

R1 = {"lui", "auipc", "jal", "jalr", "beq", "bne", "blt", "bge", "bltu", "bgeu", "lb", "lh", "lw",
      "lbu", "lhu", "sb", "sh", "sw", "addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli",
      "srai", "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and", "fence",
      "ecall", "ebreak", "mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu",
      "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci", "mret"}
R2 = {"andi", "addi", "xori", "slli", "lui", "add", "sltu", "or", "and", "jal", "beq", "bne", "blt",
      "lw", "lbu", "lhu", "sb", "sw", "ecall", "ebreak", "mret",
      "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci"}
IMEM_WORDS = 256


def run(*cmd):
    return subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


def main():
    elf, out, core = sys.argv[1], sys.argv[2], sys.argv[3]
    llvm = sys.argv[4] if len(sys.argv) > 4 else "/usr/lib/llvm-18/bin"
    os.makedirs(out, exist_ok=True)

    # --- instruction set check on the real machine code (pseudo-instructions do not exist here)
    dis = run(f"{llvm}/llvm-objdump", "-d", "-M", "no-aliases", "--no-show-raw-insn", elf)
    used = {}
    for line in dis.splitlines():
        m = re.match(r"^\s*[0-9a-f]+:\s+([a-z][a-z0-9.]*)", line)
        if m:
            used[m.group(1)] = used.get(m.group(1), 0) + 1
    allowed = R1 if core == "r1" else R2
    bad = sorted(set(used) - allowed)
    if bad:
        raise SystemExit(f"[make_mem] {core.upper()} cannot execute: {bad}")
    with open(os.path.join(out, "program.dis"), "w") as f:
        f.write(dis)

    # --- IMEM
    tmp = os.path.join(out, "_imem.bin")
    run(f"{llvm}/llvm-objcopy", "-O", "binary", "--only-section=.text", elf, tmp)
    code = open(tmp, "rb").read()
    os.remove(tmp)
    words = (len(code) + 3) // 4
    if words > IMEM_WORDS:
        raise SystemExit(f"[make_mem] program is {words} words, IMEM holds {IMEM_WORDS}")
    code += b"\0" * (4 * words - len(code))
    with open(os.path.join(out, "memoryi.mem"), "w") as f:
        for w in range(words):
            f.write(f"{int.from_bytes(code[4*w:4*w+4], 'little'):08X}\n")

    # --- DMEM: initialised sections, then zero-fill up to _dmem_end (covers .bss)
    syms = {}
    for line in run(f"{llvm}/llvm-nm", elf).splitlines():
        p = line.split()
        if len(p) == 3:
            syms[p[2]] = int(p[0], 16)
    dmem_end = syms["_dmem_end"]
    tmp = os.path.join(out, "_dmem.bin")
    run(f"{llvm}/llvm-objcopy", "-O", "binary", "--only-section=.result", "--only-section=.rodata",
        "--only-section=.data", elf, tmp)
    data = open(tmp, "rb").read()
    os.remove(tmp)
    data += b"\0" * (dmem_end - len(data))
    with open(os.path.join(out, "memoryd.mem"), "w") as f:
        for w in range(dmem_end // 4):
            f.write(f"{int.from_bytes(data[4*w:4*w+4], 'little'):08X}\n")

    with open(os.path.join(out, "isa_used.txt"), "w") as f:
        for mn in sorted(used, key=lambda m: -used[m]):
            f.write(f"{mn} {used[mn]}\n")
    print(f"[make_mem] {core.upper()}: memoryi.mem {words}/{IMEM_WORDS} words, memoryd.mem "
          f"{dmem_end // 4} words, stack top {syms['_stack_top']:#x}, "
          f"{len(used)} distinct instructions: {' '.join(sorted(used))}")


if __name__ == "__main__":
    main()
