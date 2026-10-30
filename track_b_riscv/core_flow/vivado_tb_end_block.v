    // =====================================================================================
    // End-of-program report for MLIR-generated programs (paste before 'endmodule' in
    // riscv_tcm_top_tb.v). The program stores its predicted class to DMEM[0] exactly once,
    // as its last action; the run stops there and prints a summary in the same style as
    // "=== PROGRAM EXECUTION COMPLETED ===".
    //
    // Instruction counts come from the core's writeback stage (each instruction counted once
    // when it completes), so the profile excludes wrong-path prefetches. "Instructions Fetched"
    // is the testbench's own instruction_count (fetch-based), as printed in the paper runs.
    // =====================================================================================
    integer    rp_cnt [0:40];
    integer    rp_retired, rp_i;
    reg [31:0] rp_result_cycle;
    reg        rp_done;
    initial begin
        for (rp_i = 0; rp_i <= 40; rp_i = rp_i + 1) rp_cnt[rp_i] = 0;
        rp_retired = 0; rp_result_cycle = 0; rp_done = 0;
    end

    // RV32IM instruction -> class index (names in rp_name below)
    function integer rp_class;
        input [31:0] op;
        reg [2:0] f3; reg [6:0] f7;
        begin
            f3 = op[14:12]; f7 = op[31:25];
            case (op[6:0])
                7'b0110111: rp_class = 0;                       // LUI
                7'b0010111: rp_class = 1;                       // AUIPC
                7'b1101111: rp_class = 2;                       // JAL
                7'b1100111: rp_class = 3;                       // JALR
                7'b1100011: case (f3)                           // branches
                                3'd0: rp_class = 4;  3'd1: rp_class = 5;  3'd4: rp_class = 6;
                                3'd5: rp_class = 7;  3'd6: rp_class = 8;  default: rp_class = 9;
                            endcase
                7'b0000011: case (f3)                           // loads
                                3'd0: rp_class = 10; 3'd1: rp_class = 11; 3'd2: rp_class = 12;
                                3'd4: rp_class = 13; default: rp_class = 14;
                            endcase
                7'b0100011: case (f3)                           // stores
                                3'd0: rp_class = 15; 3'd1: rp_class = 16; default: rp_class = 17;
                            endcase
                7'b0010011: case (f3)                           // ALU immediate
                                3'd0: rp_class = 18; 3'd2: rp_class = 19; 3'd3: rp_class = 20;
                                3'd4: rp_class = 21; 3'd6: rp_class = 22; 3'd7: rp_class = 23;
                                3'd1: rp_class = 24;
                                default: rp_class = f7[5] ? 26 : 25;
                            endcase
                7'b0110011: if (f7 == 7'd1) rp_class = 37;      // RV32M
                            else case (f3)                      // ALU register
                                3'd0: rp_class = f7[5] ? 28 : 27; 3'd1: rp_class = 29;
                                3'd2: rp_class = 30; 3'd3: rp_class = 31; 3'd4: rp_class = 32;
                                3'd5: rp_class = f7[5] ? 34 : 33; 3'd6: rp_class = 35;
                                default: rp_class = 36;
                            endcase
                7'b1110011: rp_class = 38;                      // SYSTEM / CSR
                7'b0001111: rp_class = 39;                      // FENCE
                default:    rp_class = 40;
            endcase
        end
    endfunction

    function [63:0] rp_name;
        input integer c;
        begin
            case (c)
                0: rp_name = "LUI";   1: rp_name = "AUIPC"; 2: rp_name = "JAL";   3: rp_name = "JALR";
                4: rp_name = "BEQ";   5: rp_name = "BNE";   6: rp_name = "BLT";   7: rp_name = "BGE";
                8: rp_name = "BLTU";  9: rp_name = "BGEU";  10: rp_name = "LB";   11: rp_name = "LH";
                12: rp_name = "LW";   13: rp_name = "LBU";  14: rp_name = "LHU";  15: rp_name = "SB";
                16: rp_name = "SH";   17: rp_name = "SW";   18: rp_name = "ADDI"; 19: rp_name = "SLTI";
                20: rp_name = "SLTIU";21: rp_name = "XORI"; 22: rp_name = "ORI";  23: rp_name = "ANDI";
                24: rp_name = "SLLI"; 25: rp_name = "SRLI"; 26: rp_name = "SRAI"; 27: rp_name = "ADD";
                28: rp_name = "SUB";  29: rp_name = "SLL";  30: rp_name = "SLT";  31: rp_name = "SLTU";
                32: rp_name = "XOR";  33: rp_name = "SRL";  34: rp_name = "SRA";  35: rp_name = "OR";
                36: rp_name = "AND";  37: rp_name = "MUL/DIV"; 38: rp_name = "SYSTEM"; 39: rp_name = "FENCE";
                default: rp_name = "OTHER";
            endcase
        end
    endfunction

    // count every instruction that completes (writeback, no exception)
    always @(posedge clk_i)
        if (!rst_cpu_i && !rp_done && dut.u_core.u_issue.pipe_valid_wb_w
            && dut.u_core.u_issue.pipe_exception_wb_w == 0) begin
            rp_retired <= rp_retired + 1;
            rp_cnt[rp_class(dut.u_core.u_issue.pipe_opc_wb_w)] <= rp_cnt[rp_class(dut.u_core.u_issue.pipe_opc_wb_w)] + 1;
        end

    // end of program = the single store to DMEM[0]
    always @(posedge clk_i) begin
        if (!rst_cpu_i && !rp_done && (|dut.u_tcm.u_ram.wr1_i) && dut.u_tcm.u_ram.addr1_i == 32'h0) begin
            rp_done <= 1'b1;
            rp_result_cycle <= cycle_count;
            #(CLK_PERIOD * 5);
            $display("\n=== PROGRAM EXECUTION COMPLETED (result stored to DMEM[0]) ===");
            $display("Predicted Class (DMEM[0]): %0d", dut.u_tcm.u_ram.data_mem[0]);
            $display("Total Clock Cycles:   %0d", rp_result_cycle);
            $display("Instructions Retired: %0d", rp_retired);
            $display("Instructions Fetched: %0d", instruction_count);
            $display("CPI:                  %0.3f", rp_result_cycle * 1.0 / rp_retired);
            $display("Execution Time:       %0.2f ns  (%0.6f ms)", rp_result_cycle * 1.0 * CLK_PERIOD,
                     rp_result_cycle * 1.0 * CLK_PERIOD / 1.0e6);
            $display("Clock Frequency:      %0.2f MHz", 1000.0 / CLK_PERIOD);
            $display("\n=== INSTRUCTION PROFILE (retired) ===");
            for (rp_i = 0; rp_i <= 40; rp_i = rp_i + 1)
                if (rp_cnt[rp_i] > 0)
                    $display("%-8s: %0d  (%0.2f%%)", rp_name(rp_i), rp_cnt[rp_i], 100.0 * rp_cnt[rp_i] / rp_retired);
            $display("Memory Ops %%: %0.2f%%", 100.0 * (rp_cnt[10] + rp_cnt[11] + rp_cnt[12] + rp_cnt[13]
                     + rp_cnt[14] + rp_cnt[15] + rp_cnt[16] + rp_cnt[17]) / rp_retired);
            print_memory_contents();
            $finish;
        end
    end
