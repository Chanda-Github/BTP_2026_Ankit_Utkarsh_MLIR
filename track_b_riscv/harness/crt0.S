# Minimal bare-metal startup for Spike (RV32I only, no CSR access).
# Sets up the stack, calls main(), and reports main's return value to Spike through
# the HTIF 'tohost' word:  tohost = (code << 1) | 1  ->  Spike exits with status 'code'.
    .section .text.init
    .globl _start
_start:
    la    sp, _stack_top
    call  main
    slli  a0, a0, 1
    ori   a0, a0, 1
    la    t0, tohost
    sw    a0, 0(t0)
1:  j     1b

    .section .tohost, "aw", @progbits
    .align 6
    .globl tohost
tohost:   .dword 0
    .align 6
    .globl fromhost
fromhost: .dword 0
