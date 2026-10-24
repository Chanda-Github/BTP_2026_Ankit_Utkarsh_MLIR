/* Spike's default DRAM starts at 0x80000000 */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .text   : { *(.text.init) *(.text .text.*) }
  .rodata : { *(.rodata .rodata.* .srodata .srodata.*) }
  .tohost : { *(.tohost) }
  .data   : { *(.data .data.* .sdata .sdata.*) }
  .bss    : { *(.bss .bss.* .sbss .sbss.* COMMON) }
  . = ALIGN(16);
  . += 0x4000;
  _stack_top = .;
}
