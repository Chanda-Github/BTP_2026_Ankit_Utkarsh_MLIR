# RV32I usage profile: `out/iris`

- Kernel (`tm_infer`) uses **10 / 40** RV32I instructions
- Whole program (kernel + harness + startup) uses **20 / 40**
- RV32M (mul/div) instructions used: **none**
- Instructions outside RV32I: **none**

| Group | Instruction | Kernel static | Kernel dynamic | Harness static | Harness dynamic |
|---|---|---:|---:|---:|---:|
| U-type | `lui` | 0 | 0 | 1 | 1 |
| U-type | `auipc` | 0 | 0 | 2 | 2 |
| Jump | `jal` | 0 | 0 | 3 | 258 |
| Jump | `jalr` | 1 | 256 | 1 | 1 |
| Branch | `bne` | 0 | 0 | 1 | 256 |
| Load | `lw` | 1 | 256 | 5 | 5 |
| Load | `lbu` | 0 | 0 | 1 | 256 |
| Store | `sw` | 1 | 256 | 6 | 6 |
| ALU-imm | `addi` | 2 | 512 | 10 | 265 |
| ALU-imm | `slti` | 1 | 256 | 0 | 0 |
| ALU-imm | `xori` | 9 | 2304 | 0 | 0 |
| ALU-imm | `ori` | 0 | 0 | 1 | 1 |
| ALU-imm | `andi` | 10 | 2560 | 1 | 256 |
| ALU-imm | `slli` | 0 | 0 | 8 | 1793 |
| ALU-imm | `srli` | 0 | 0 | 7 | 1792 |
| ALU-reg | `add` | 8 | 2048 | 2 | 512 |
| ALU-reg | `sub` | 1 | 256 | 0 | 0 |
| ALU-reg | `sltu` | 0 | 0 | 1 | 256 |
| ALU-reg | `xor` | 0 | 0 | 1 | 256 |
| ALU-reg | `and` | 10 | 2560 | 0 | 0 |

Unused RV32I instructions (candidates for removal, safe because the static analysis covers all paths): `beq`, `blt`, `bge`, `bltu`, `bgeu`, `lb`, `lh`, `lhu`, `sb`, `sh`, `sltiu`, `srai`, `sll`, `slt`, `srl`, `sra`, `or`, `fence`, `ecall`, `ebreak`
