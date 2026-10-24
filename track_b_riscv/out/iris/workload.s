	.text
	.attribute	4, 16
	.attribute	5, "rv32i2p1"
	.file	"LLVMDialectModule"
	.globl	tm_infer                        # -- Begin function tm_infer
	.p2align	2
	.type	tm_infer,@function
tm_infer:                               # @tm_infer
	.cfi_startproc
# %bb.0:
	addi	sp, sp, -16
	.cfi_def_cfa_offset 16
	sw	s0, 12(sp)                      # 4-byte Folded Spill
	.cfi_offset s0, -4
	not	t0, a0
	not	t1, a1
	not	t2, a2
	not	t3, a3
	not	t4, a4
	xori	t5, a5, 1
	xori	t6, a6, 1
	not	s0, a7
	and	a0, a0, a3
	andi	a0, a0, 1
	and	a3, a4, a6
	andi	a3, a3, 1
	and	a1, a1, a5
	andi	a1, a1, 1
	and	a2, a2, a7
	andi	a2, a2, 1
	and	a4, a5, a6
	andi	a4, a4, 1
	and	a5, t0, t3
	andi	a5, a5, 1
	and	a6, t4, t6
	andi	a6, a6, 1
	and	a7, t1, t5
	andi	a7, a7, 1
	and	t0, t2, s0
	andi	t0, t0, 1
	and	t1, t5, t6
	andi	t1, t1, 1
	add	a0, a0, a3
	add	a1, a1, a2
	add	a0, a0, a1
	add	a0, a0, a4
	add	a5, a5, a6
	add	a7, a7, t0
	add	a5, a5, a7
	add	a5, a5, t1
	sub	a0, a0, a5
	slti	a0, a0, 0
	xori	a0, a0, 1
	lw	s0, 12(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 16
	ret
.Lfunc_end0:
	.size	tm_infer, .Lfunc_end0-tm_infer
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
