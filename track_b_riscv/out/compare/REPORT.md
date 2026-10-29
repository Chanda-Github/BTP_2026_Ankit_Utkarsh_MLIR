# Paper flow vs MLIR flow on the same core (Icarus, lab testbench)

Same trained model, same input sample (the one stored in the paper's memoryd.mem), same R1/R2 Verilog. Votes are read from data memory after each run; golden = computed directly from the clauses.

Paper status: `OK` = equals the golden model; `= bge-swap semantics` = equals exactly what the hand-edited assembly computes after rewriting `bge x,y` as `blt y,x` (clause C/2 votes +1 instead of -1, ties go to the last class), which the golden model also predicts.

| Case | Core | Golden class | Paper class | MLIR class | Golden votes | Paper votes | MLIR votes | Paper status | Paper cycles | MLIR cycles | Speed-up |
|---|---|:-:|:-:|:-:|---|---|---|---|---:|---:|---:|
| iris/4/t1 | R1 | 2 | 2 | 2 | [2, 2, 6] | [4, 4, 6] | [2, 2, 6] | = bge-swap semantics | 20,714 | 3,916 | 5.3x |
| iris/4/t1 | R2 | 2 | 2 | 2 | [2, 2, 6] | [4, 4, 6] | [2, 2, 6] | = bge-swap semantics | 20,714 | 3,928 | 5.3x |
| iris/4/t2 | R1 | 2 | 2 | 2 | [2, 2, 6] | [4, 4, 6] | [2, 2, 6] | = bge-swap semantics | 3,319 | 756 | 4.4x |
| iris/4/t2 | R2 | 2 | 2 | 2 | [2, 2, 6] | [4, 4, 6] | [2, 2, 6] | = bge-swap semantics | 3,319 | 787 | 4.2x |
| mammography/10/t1 | R1 | 1 | 1 | 1 | [6, 13] | [6, 13] | [6, 13] | OK | 42,194 | 7,826 | 5.4x |
| mammography/10/t1 | R2 | 1 | 1 | 1 | [6, 13] | [6, 13] | [6, 13] | OK | 42,194 | 7,840 | 5.4x |
| mammography/50/t2 | R1 | 0 | 0 | 0 | [55, 48] | [55, 48] | [55, 48] | OK | 24,697 | 5,022 | 4.9x |
| mammography/50/t2 | R2 | 0 | 0 | 0 | [55, 48] | [55, 48] | [55, 48] | OK | 24,697 | 5,221 | 4.7x |
| statlog/100/t2 | R1 | 3 | 3 | 3 | [82, 92, 87, 107] | [82, 94, 87, 107] | [82, 92, 87, 107] | = bge-swap semantics | 418,380 | 70,646 | 5.9x |
| statlog/100/t2 | R2 | 3 | 3 | 3 | [82, 92, 87, 107] | [82, 94, 87, 107] | [82, 92, 87, 107] | = bge-swap semantics | 418,380 | 75,041 | 5.6x |
| har/200/t2 | R1 | 4 | 4 | 4 | [186, 186, 189, 172, 215, 151] | [186, 186, 189, 172, 215, 153] | [186, 186, 189, 172, 215, 151] | = bge-swap semantics | 345,292 | 66,886 | 5.2x |
| har/200/t2 | R2 | 4 | 4 | 4 | [186, 186, 189, 172, 215, 151] | [186, 186, 189, 172, 215, 153] | [186, 186, 189, 172, 215, 151] | = bge-swap semantics | 345,292 | 69,622 | 5.0x |
