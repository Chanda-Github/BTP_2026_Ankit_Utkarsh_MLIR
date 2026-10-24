#!/usr/bin/env python3
"""
rewrite_r2.py <in.s> <out.s> [--harness]
=========================================
Rewrites RV32I instructions that the reduced core R2 (new-RISCV/rv32im_2_mod3_2) does not decode
into exactly equivalent sequences of instructions it does decode.

R2 base instructions (riscv_decoder.v): andi addi xori slli lui add sltu or and jal beq bne blt
                                        lw lbu lhu sb sw  (+ ecall ebreak eret, csr*)
Scratch register: x31 (t6). The code generator is run with -mattr=+reserve-x31, so the compiler
never allocates it and every rewrite may clobber it freely.

Every rule is an identity for all operand values (unlike 'bge x,y -> blt y,x', which differs when
x == y). Correctness is also checked end-to-end: the rewritten program runs on Spike against the
golden model.
Anything not covered here makes the script fail rather than emit code R2 cannot run.
--harness: keep jalr/auipc (call/return of the Spike test harness only; make_mem.py rejects them
           in a core image).
"""
import re
import sys

R2_BASE = {"andi", "addi", "xori", "slli", "lui", "add", "sltu", "or", "and", "jal", "beq", "bne",
           "blt", "lw", "lbu", "lhu", "sb", "sw", "ecall", "ebreak", "eret"}
SCR = "t6"

_n = 0


def fresh():
    global _n
    _n += 1
    return f".Lr2_{_n}"


def rewrite(mn, ops):
    """Returns a list of replacement lines, or None if mn is natively supported."""
    if mn in R2_BASE:
        return None
    if mn == "sub":                       # rd = a - b = a + (~b + 1)
        rd, a, b = ops
        return [f"xori {SCR}, {b}, -1", f"addi {SCR}, {SCR}, 1", f"add {rd}, {a}, {SCR}"]
    if mn == "bge":                       # if !(a < b) goto L
        a, b, L = ops
        s = fresh()
        return [f"blt {a}, {b}, {s}", f"jal zero, {L}", f"{s}:"]
    if mn == "bltu":
        a, b, L = ops
        return [f"sltu {SCR}, {a}, {b}", f"bne {SCR}, zero, {L}"]
    if mn == "bgeu":
        a, b, L = ops
        return [f"sltu {SCR}, {a}, {b}", f"beq {SCR}, zero, {L}"]
    if mn == "slt":                       # rd = (a < b) signed, via a branch (reads a,b first)
        rd, a, b = ops
        t, e = fresh(), fresh()
        return [f"blt {a}, {b}, {t}", f"addi {rd}, zero, 0", f"jal zero, {e}",
                f"{t}:", f"addi {rd}, zero, 1", f"{e}:"]
    if mn == "slti":
        rd, a, imm = ops
        return [f"addi {SCR}, zero, {imm}"] + rewrite("slt", [rd, a, SCR])
    if mn == "sltiu":                     # imm is sign-extended then compared unsigned, as addi does
        rd, a, imm = ops
        return [f"addi {SCR}, zero, {imm}", f"sltu {rd}, {a}, {SCR}"]
    if mn == "ori":
        rd, a, imm = ops
        return [f"addi {SCR}, zero, {imm}", f"or {rd}, {a}, {SCR}"]
    if mn == "xor":                       # a ^ b = (a | b) & ~(a & b)
        rd, a, b = ops
        return [f"and {SCR}, {a}, {b}", f"xori {SCR}, {SCR}, -1", f"or {rd}, {a}, {b}",
                f"and {rd}, {rd}, {SCR}"]
    raise SystemExit(f"rewrite_r2: no R2-safe rewrite for '{mn} {', '.join(ops)}' -- "
                     f"extend rewrite_r2.py or change the kernel")


INSN = re.compile(r"^(\s+)([a-z][a-z0-9.]*)\s+(.*?)\s*(#.*)?$")


HARNESS_ONLY = {"jalr", "auipc"}   # call/return of the Spike test harness (never in a core image)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    harness = "--harness" in sys.argv[3:]
    out, counts = [], {}
    for line in open(src):
        line = line.rstrip("\n")
        m = INSN.match(line)
        if not m or m.group(2).startswith("."):
            out.append(line)
            continue
        ind, mn, args = m.group(1), m.group(2), m.group(3)
        ops = [o.strip() for o in args.split(",")] if args else []
        rep = None if (harness and mn in HARNESS_ONLY) else rewrite(mn, ops)
        if rep is None:
            out.append(line)
        else:
            counts[mn] = counts.get(mn, 0) + 1
            out.append(f"{ind}# R2 rewrite of: {mn} {args}")
            out += [(l if l.endswith(":") else ind + l) for l in rep]
    open(dst, "w").write("\n".join(out) + "\n")
    print(f"[rewrite_r2] {sum(counts.values())} instructions rewritten: {counts or 'none'}")


if __name__ == "__main__":
    main()
