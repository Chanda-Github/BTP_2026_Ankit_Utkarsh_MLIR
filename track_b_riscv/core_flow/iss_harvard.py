#!/usr/bin/env python3
"""
iss_harvard.py <memoryi.mem> <memoryd.mem> [--max-steps N] [--watch ADDR]
=========================================================================
Minimal RV32I instruction-set simulator with SEPARATE instruction and data memories, both at
address 0 (like the UltraEmbedded TCM core). No pipeline, no timing: pure ISA semantics.
Used to tell a program bug from a core bug: if a memory image misbehaves here too, the cause is
in the program/data image, not in the RTL.

Runs from PC 0 until the program jumps back to PC 0 (end of the paper's programs: ret with
ra = 0), an unknown instruction, or --max-steps. Reports DMEM[0] (result), stores to the watched
address range [ADDR, ADDR+8), and the step count.
"""
import argparse


def load(path):
    return [int(l, 16) for l in open(path) if l.strip()]


def sx(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("imem")
    ap.add_argument("dmem")
    ap.add_argument("--max-steps", type=int, default=200_000_000)
    ap.add_argument("--watch", type=int, default=0)
    ap.add_argument("--store-trace", help="write every store as 'ST <word> <strobe> <data>' to this file")
    a = ap.parse_args()
    imem = load(a.imem)
    words = load(a.dmem)
    dm = bytearray(2_000_004)
    for i, w in enumerate(words):
        dm[4 * i:4 * i + 4] = w.to_bytes(4, "little")
    st = open(a.store_trace, "w") if a.store_trace else None
    x = [0] * 32
    pc, steps, watch_hits, first_hit = 0, 0, 0, None
    M = 0xFFFFFFFF
    while steps < a.max_steps:
        if pc // 4 >= len(imem):
            print(f"PC {pc:#x} outside the program"); break
        ins = imem[pc // 4]
        op, rd, f3, rs1, rs2, f7 = ins & 0x7F, (ins >> 7) & 31, (ins >> 12) & 7, (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
        i_imm = sx(ins >> 20, 12)
        s_imm = sx(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)
        b_imm = sx(((ins >> 31) << 12) | (((ins >> 7) & 1) << 11) | (((ins >> 25) & 63) << 5) | (((ins >> 8) & 15) << 1), 13)
        j_imm = sx(((ins >> 31) << 20) | (((ins >> 12) & 255) << 12) | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 1023) << 1), 21)
        r1, r2 = x[rs1], x[rs2]
        npc = pc + 4
        v = None
        if op == 0x37: v = ins & 0xFFFFF000
        elif op == 0x17: v = (pc + (ins & 0xFFFFF000)) & M
        elif op == 0x6F: v = pc + 4; npc = (pc + j_imm) & M
        elif op == 0x67: v = pc + 4; npc = (r1 + i_imm) & ~1 & M
        elif op == 0x63:
            s1, s2 = sx(r1, 32), sx(r2, 32)
            t = {0: r1 == r2, 1: r1 != r2, 4: s1 < s2, 5: s1 >= s2, 6: r1 < r2, 7: r1 >= r2}[f3]
            if t: npc = (pc + b_imm) & M
        elif op == 0x03:
            ad = (r1 + i_imm) & M
            if f3 == 0: v = sx(dm[ad], 8) & M
            elif f3 == 1: v = sx(int.from_bytes(dm[ad:ad + 2], "little"), 16) & M
            elif f3 == 2: v = int.from_bytes(dm[ad:ad + 4], "little")
            elif f3 == 4: v = dm[ad]
            elif f3 == 5: v = int.from_bytes(dm[ad:ad + 2], "little")
        elif op == 0x23:
            ad = (r1 + s_imm) & M
            n = {0: 1, 1: 2, 2: 4}[f3]
            dm[ad:ad + n] = (r2 & ((1 << (8 * n)) - 1)).to_bytes(n, "little")
            if st:
                lane = ad & 3
                strobe = ((1 << n) - 1) << lane
                data = ((r2 & ((1 << (8 * n)) - 1)) << (8 * lane)) & M
                st.write(f"ST {ad >> 2} {strobe:x} {data:x} pc={pc:#x} step={steps}\n")
            if a.watch <= ad < a.watch + 8:
                watch_hits += 1
                first_hit = first_hit if first_hit is not None else (steps, pc, ad, r2)
        elif op == 0x13:
            sh = (ins >> 20) & 31
            v = {0: r1 + i_imm, 2: int(sx(r1, 32) < i_imm), 3: int(r1 < (i_imm & M)), 4: r1 ^ (i_imm & M),
                 6: r1 | (i_imm & M), 7: r1 & (i_imm & M), 1: r1 << sh,
                 5: (sx(r1, 32) >> sh) if f7 & 0x20 else (r1 >> sh)}[f3] & M
        elif op == 0x33:
            if f7 == 1:
                print(f"M-extension instruction at {pc:#x}"); break
            sh = r2 & 31
            v = {(0, 0): r1 + r2, (0, 0x20): r1 - r2, (1, 0): r1 << sh, (2, 0): int(sx(r1, 32) < sx(r2, 32)),
                 (3, 0): int(r1 < r2), (4, 0): r1 ^ r2, (5, 0): r1 >> sh, (5, 0x20): sx(r1, 32) >> sh,
                 (6, 0): r1 | r2, (7, 0): r1 & r2}[(f3, f7)] & M
        else:
            print(f"unsupported instruction {ins:#010x} at {pc:#x}"); break
        if v is not None and rd:
            x[rd] = v & M
        steps += 1
        if npc == 0 and steps > 4:
            break
        pc = npc
    print(f"steps={steps} DMEM[0]={int.from_bytes(dm[0:4], 'little')} "
          f"stores_to_[{a.watch},{a.watch + 8})={watch_hits}"
          + (f" first at step {first_hit[0]} pc={first_hit[1]:#x} addr={first_hit[2]} value={first_hit[3]}"
             if first_hit else ""))


if __name__ == "__main__":
    main()
