# CoDALab trained TMs: MLIR -> RV32I instruction needs

Every model: Spike `--isa=rv32i`, all test vectors match the golden model.

**What is counted:** only the `tm_infer` function generated from each model by this MLIR pipeline (model compiled into straight-line code), read from `llvm-objdump -M no-aliases` of the real ELF, so pseudo-instructions already appear as the real RV32I instruction. The test harness is excluded. This is *not* the CoDALab generic `predict` program (loops over clause data in memory), which uses a different set: `add addi and andi beq blt jal jalr lbu lui lw or sb slli sltu sw xori` (17, after expanding `j`, `beqz`, `li`, `mv`, `nop`, `zext.b`, `snez`, `ret`).

**Note on large models:** most `lw`/`sw`/`lui` here are register spills: the straight-line code keeps more values live than RV32I's 31 registers, and stack offsets beyond 2 KB need `lui`+`add` to form the address.

| Model | Classes | Clauses/class | Features | Test acc % | Kernel insns used (/40) | Kernel size (insns) | Executed per inference |
|---|---:|---:|---:|---:|---:|---:|---:|
| emg_50 | 8 | 50 | 160 | 80.26 | 14 | 14170 | 14159.0 |
| emg_100 | 8 | 100 | 160 | 84.58 | 15 | 24841 | 24829.9 |
| emg_150 | 8 | 150 | 160 | 85.39 | 15 | 34795 | 34784.0 |
| emg_200 | 8 | 200 | 160 | 86.02 | 15 | 51079 | 51068.0 |
| emg_250 | 8 | 250 | 160 | 86.06 | 15 | 54880 | 54869.0 |
| emg_300 | 8 | 300 | 160 | 85.77 | 15 | 57105 | 57093.7 |
| gas_50 | 6 | 50 | 128 | 72.91 | 14 | 22584 | 22576.7 |
| gas_100 | 6 | 100 | 128 | 84.96 | 14 | 37153 | 37145.6 |
| gas_150 | 6 | 150 | 128 | 85.54 | 14 | 33908 | 33900.9 |
| gas_200 | 6 | 200 | 128 | 86.29 | 15 | 39311 | 39304.0 |
| gas_250 | 6 | 250 | 128 | 86.94 | 15 | 51444 | 51436.8 |
| gas_300 | 6 | 300 | 128 | 86.87 | 15 | 53293 | 53285.9 |
| gesture_50 | 5 | 50 | 180 | 64.16 | 14 | 29784 | 29778.2 |
| gesture_100 | 5 | 100 | 180 | 68.0 | 14 | 41362 | 41356.1 |
| gesture_150 | 5 | 150 | 180 | 70.97 | 15 | 77851 | 77845.0 |
| gesture_200 | 5 | 200 | 180 | 73.6 | 15 | 105817 | 105810.9 |
| gesture_250 | 5 | 250 | 180 | 74.96 | 15 | 129521 | 129514.8 |
| gesture_300 | 5 | 300 | 180 | 75.92 | 15 | 153299 | 153292.8 |
| gesture_400 | 5 | 400 | 180 | 79.25 | 15 | 170480 | 170472.0 |
| gesture_500 | 5 | 500 | 180 | 81.73 | 15 | 213846 | 213838.0 |
| har_50 | 6 | 50 | 560 | 80.01 | 15 | 44295 | 44288.1 |
| har_100 | 6 | 100 | 560 | 86.33 | 15 | 100310 | 100300.4 |
| har_150 | 6 | 150 | 560 | 88.19 | 15 | 132639 | 132632.3 |
| har_200 | 6 | 200 | 560 | 87.99 | 15 | 164146 | 164138.7 |
| iris_4 | 3 | 4 | 12 | 96.67 | 14 | 90 | 88.0 |
| iris_10 | 3 | 10 | 12 | 93.33 | 14 | 115 | 113.0 |
| iris_20 | 3 | 20 | 12 | 96.67 | 14 | 126 | 124.1 |
| iris_50 | 3 | 50 | 12 | 96.67 | 14 | 221 | 219.1 |
| iris_100 | 3 | 100 | 12 | 90.0 | 14 | 353 | 351.0 |
| iris_150 | 3 | 150 | 12 | 90.0 | 14 | 483 | 480.7 |
| iris_200 | 3 | 200 | 12 | 96.67 | 14 | 543 | 541.1 |
| mammography_4 | 2 | 4 | 15 | 79.79 | 11 | 116 | 116.0 |
| mammography_10 | 2 | 10 | 15 | 84.46 | 11 | 190 | 190.0 |
| mammography_20 | 2 | 20 | 15 | 83.94 | 11 | 224 | 224.0 |
| mammography_50 | 2 | 50 | 15 | 83.42 | 11 | 355 | 355.0 |
| mammography_100 | 2 | 100 | 15 | 83.94 | 11 | 716 | 716.0 |
| mammography_150 | 2 | 150 | 15 | 83.42 | 11 | 805 | 805.0 |
| mammography_200 | 2 | 200 | 15 | 83.94 | 11 | 1175 | 1175.0 |
| sports_50 | 19 | 50 | 45 | 86.02 | 14 | 8393 | 8360.9 |
| sports_100 | 19 | 100 | 45 | 91.59 | 14 | 14418 | 14385.8 |
| sports_150 | 19 | 150 | 45 | 93.11 | 15 | 25932 | 25899.7 |
| sports_200 | 19 | 200 | 45 | 94.59 | 15 | 37681 | 37620.8 |
| sports_250 | 19 | 250 | 45 | 94.3 | 15 | 45819 | 45758.5 |
| sports_300 | 19 | 300 | 45 | 94.92 | 15 | 54856 | 54795.1 |
| statlog_50 | 4 | 50 | 360 | 76.47 | 15 | 13558 | 13553.0 |
| statlog_100 | 4 | 100 | 360 | 78.82 | 15 | 31331 | 31326.9 |
| statlog_150 | 4 | 150 | 360 | 78.24 | 15 | 32624 | 32619.9 |
| statlog_200 | 4 | 200 | 360 | 80.0 | 15 | 35570 | 35565.9 |
| statlog_250 | 4 | 250 | 360 | 80.59 | 15 | 41634 | 41630.0 |
| statlog_300 | 4 | 300 | 360 | 80.0 | 15 | 31903 | 31898.9 |

**Union over all 50 models: 15 / 40 RV32I instructions** (`lui`, `jal`, `jalr`, `blt`, `bge`, `lw`, `lbu`, `sw`, `addi`, `xori`, `andi`, `add`, `sub`, `slt`, `and`)

RV32M (multiply/divide) used by any model: **none**

Never used by any kernel: `auipc`, `beq`, `bne`, `bltu`, `bgeu`, `lb`, `lh`, `lhu`, `sb`, `sh`, `slti`, `sltiu`, `ori`, `slli`, `srli`, `srai`, `sll`, `sltu`, `xor`, `srl`, `sra`, `or`, `fence`, `ecall`, `ebreak`
