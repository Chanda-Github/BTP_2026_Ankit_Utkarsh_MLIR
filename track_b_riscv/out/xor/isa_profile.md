# RV32I usage profile: `out/xor`

- Kernel (`tm_infer`) uses **7 / 40** RV32I instructions
- Whole program (kernel + harness + startup) uses **14 / 40**
- RV32M (mul/div) instructions used: **none**
- Instructions outside RV32I: **none**

| Group | Instruction | Kernel static | Kernel dynamic | Harness static | Harness dynamic |
|---|---|---:|---:|---:|---:|
| U-type | `auipc` | 0 | 0 | 2 | 2 |
| Jump | `jal` | 0 | 0 | 6 | 6 |
| Jump | `jalr` | 1 | 4 | 1 | 1 |
| Load | `lw` | 0 | 0 | 3 | 3 |
| Store | `sw` | 0 | 0 | 4 | 4 |
| ALU-imm | `addi` | 0 | 0 | 13 | 13 |
| ALU-imm | `slti` | 1 | 4 | 0 | 0 |
| ALU-imm | `xori` | 3 | 12 | 2 | 2 |
| ALU-imm | `ori` | 0 | 0 | 1 | 1 |
| ALU-imm | `andi` | 4 | 16 | 0 | 0 |
| ALU-imm | `slli` | 0 | 0 | 1 | 1 |
| ALU-reg | `add` | 2 | 8 | 3 | 3 |
| ALU-reg | `sub` | 1 | 4 | 0 | 0 |
| ALU-reg | `and` | 4 | 16 | 0 | 0 |

Unused RV32I instructions (candidates for removal, safe because the static analysis covers all paths): `lui`, `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`, `lb`, `lh`, `lbu`, `lhu`, `sb`, `sh`, `sltiu`, `srli`, `srai`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `fence`, `ecall`, `ebreak`
