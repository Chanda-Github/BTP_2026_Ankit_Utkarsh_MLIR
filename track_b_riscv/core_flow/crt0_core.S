# Start-up for the UltraEmbedded TCM core (R1/R2): boot vector 0, separate IMEM/DMEM both at 0.
# Replaces the hand-written 'lui sp,139 / addi s0,sp,0 / addi a0..a7 ...' block of the paper's flow.
# Only lui/addi/jal/ecall are used, so it runs unchanged on R2 (no auipc, no jalr).
    .section .text.init, "ax"
    .globl _start
_start:
    lui   sp, %hi(_stack_top)
    addi  sp, sp, %lo(_stack_top)
    jal   zero, tm_entry          # never returns: tm_entry stores the class, then jumps to tm_halt

# End of program. The lab testbench (riscv_tcm_top_tb.v used for the ISVLSI'26 runs) ends the
# simulation when the core FETCHES an ecall. The core prefetches 2-3 words past a branch, so the
# ecall sits behind 4 nops at the very end of the program and is reached only by the explicit
# 'jal zero, tm_halt' after the result store -- a prefetch can never reach it early.
    .section .text.zz_halt, "ax"
    nop
    nop
    nop
    nop
    .globl tm_halt
tm_halt:
    ecall
1:  jal   zero, 1b
