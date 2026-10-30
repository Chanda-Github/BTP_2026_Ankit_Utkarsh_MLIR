/* UltraEmbedded riscv_tcm_top as used in the ISVLSI'26 work (new-RISCV/rv32im_2_*):
 *   tcm_mem_ram.v: instr_mem[255:0]   -> IMEM, 1 KB, read with pc[15:2]
 *                  data_mem[500000:0] -> DMEM, ~2 MB, read with addr[31:2]
 *   BOOT_VECTOR = 0, TCM_MEM_BASE = 0. The two memories are separate, so both start at 0;
 *   link with --no-check-sections because the address ranges overlap by design.
 *   The testbench prints data_mem[0..9]: the predicted class is stored at DMEM address 0. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
MEMORY
{
  IMEM (rx)  : ORIGIN = 0, LENGTH = 1K
  DMEM (rw)  : ORIGIN = 0, LENGTH = 2000000
}
SECTIONS
{
  .text   : { *(.text.init) *(EXCLUDE_FILE(*crt0_core.o) .text .text.*) *(.text.zz_halt) } > IMEM
  .result : { *(.result) . = ALIGN(4); } > DMEM
  .rodata : { *(.rodata .rodata.* .srodata .srodata.*) } > DMEM
  .data   : { *(.data .data.* .sdata .sdata.*) } > DMEM
  .bss    : { *(.bss .bss.* .sbss .sbss.* COMMON) } > DMEM
  . = ALIGN(16);
  _dmem_end = .;
  . += 0x1000;
  _stack_top = .;
}
