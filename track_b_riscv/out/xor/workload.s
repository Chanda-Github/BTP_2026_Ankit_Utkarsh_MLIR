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
	xori	a2, a0, 1
	xori	a3, a1, 1
	and	a4, a0, a3
	andi	a4, a4, 1
	and	a5, a2, a1
	andi	a5, a5, 1
	and	a0, a0, a1
	andi	a0, a0, 1
	and	a2, a2, a3
	andi	a2, a2, 1
	add	a4, a4, a5
	add	a0, a0, a2
	sub	a4, a4, a0
	slti	a0, a4, 0
	xori	a0, a0, 1
	ret
.Lfunc_end0:
	.size	tm_infer, .Lfunc_end0-tm_infer
	.cfi_endproc
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
