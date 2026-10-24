# Start-up for the UltraEmbedded TCM core (R1/R2): boot vector 0, separate IMEM/DMEM both at 0.
# Replaces the hand-written 'lui sp,139 / addi s0,sp,0 / addi a0..a7 ...' block of the paper's flow.
# Only lui/addi/jal are used, so it runs unchanged on R2 (no auipc, no jalr).
    .section .text.init, "ax"
    .globl _start
_start:
    lui   sp, %hi(_stack_top)
    addi  sp, sp, %lo(_stack_top)
    jal   zero, tm_entry          # never returns: tm_entry ends in a self-loop
