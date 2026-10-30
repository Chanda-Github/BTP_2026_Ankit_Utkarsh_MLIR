    // =====================================================================================
    // Report block for riscv_tcm_top_tb.v -- paste just before 'endmodule'.
    //
    // Prints the paper-style summary (=== PROGRAM EXECUTION COMPLETED ===, Total Clock Cycles,
    // Total Instructions, Execution Time, Clock Frequency, INSTRUCTION PROFILE, INSTRUCTION MIX,
    // Memory Ops %), counted the same way as the original testbench:
    //   * "Total Instructions" is the testbench's own instruction_count (fetch-based: an accepted
    //     fetch while the PC changes, so it includes prefetched wrong-path instructions)
    //   * the INSTRUCTION PROFILE decodes exactly those same fetches; mix % = count / Total
    // and adds a RETIRED profile (each instruction counted once at the core's writeback stage).
    //
    // STOP_ON_RESULT_STORE = 1 : MLIR-generated programs. They store the class to DMEM[0] exactly
    //                            once as their last action and then self-loop, which the
    //                            "PC stable for 100 cycles" check never sees; stop at that store.
    // STOP_ON_RESULT_STORE = 0 : paper (hand-edited) programs; the original completion check and
    //                            timeout decide when to stop, and this block prints its report
    //                            at the same moment.
    // =====================================================================================
    parameter STOP_ON_RESULT_STORE = 1;

    integer    rp_fetch [0:40];
    integer    rp_ret   [0:40];
    integer    rp_retired, rp_i, rp_tot;
    reg        rp_done;
    initial begin
        for (rp_i = 0; rp_i <= 40; rp_i = rp_i + 1) begin rp_fetch[rp_i] = 0; rp_ret[rp_i] = 0; end
        rp_retired = 0; rp_done = 0;
    end

    // RV32IM instruction -> class index (names in rp_name)
    function integer rp_class;
        input [31:0] op;
        reg [2:0] f3; reg [6:0] f7;
        begin
            f3 = op[14:12]; f7 = op[31:25];
            case (op[6:0])
                7'b0110111: rp_class = 0;
                7'b0010111: rp_class = 1;
                7'b1101111: rp_class = 2;
                7'b1100111: rp_class = 3;
                7'b1100011: case (f3)
                                3'd0: rp_class = 4;  3'd1: rp_class = 5;  3'd4: rp_class = 6;
                                3'd5: rp_class = 7;  3'd6: rp_class = 8;  default: rp_class = 9;
                            endcase
                7'b0000011: case (f3)
                                3'd0: rp_class = 10; 3'd1: rp_class = 11; 3'd2: rp_class = 12;
                                3'd4: rp_class = 13; default: rp_class = 14;
                            endcase
                7'b0100011: case (f3)
                                3'd0: rp_class = 15; 3'd1: rp_class = 16; default: rp_class = 17;
                            endcase
                7'b0010011: case (f3)
                                3'd0: rp_class = 18; 3'd2: rp_class = 19; 3'd3: rp_class = 20;
                                3'd4: rp_class = 21; 3'd6: rp_class = 22; 3'd7: rp_class = 23;
                                3'd1: rp_class = 24;
                                default: rp_class = f7[5] ? 26 : 25;
                            endcase
                7'b0110011: if (f7 == 7'd1) rp_class = 37;
                            else case (f3)
                                3'd0: rp_class = f7[5] ? 28 : 27; 3'd1: rp_class = 29;
                                3'd2: rp_class = 30; 3'd3: rp_class = 31; 3'd4: rp_class = 32;
                                3'd5: rp_class = f7[5] ? 34 : 33; 3'd6: rp_class = 35;
                                default: rp_class = 36;
                            endcase
                7'b1110011: rp_class = 38;
                7'b0001111: rp_class = 39;
                default:    rp_class = 40;      // includes undefined (x) words fetched past the program
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

    // fetch-based profile: same condition as instruction_count in the original testbench
    always @(posedge clk_i)
        if (!rst_cpu_i && !rp_done && !program_finished && dut.ifetch_pc_w != last_pc
            && dut.ifetch_valid_w && dut.ifetch_accept_w)
            rp_fetch[rp_class(dut.ifetch_inst_w)] <= rp_fetch[rp_class(dut.ifetch_inst_w)] + 1;

    // retired profile: each instruction once, at writeback, without exception
    always @(posedge clk_i)
        if (!rst_cpu_i && !rp_done && !program_finished && dut.u_core.u_issue.pipe_valid_wb_w
            && dut.u_core.u_issue.pipe_exception_wb_w == 0) begin
            rp_retired <= rp_retired + 1;
            rp_ret[rp_class(dut.u_core.u_issue.pipe_opc_wb_w)] <= rp_ret[rp_class(dut.u_core.u_issue.pipe_opc_wb_w)] + 1;
        end

    task rp_report;
        begin
            $display("\n=== PROGRAM EXECUTION COMPLETED ===");
            $display("Total Clock Cycles: %d", cycle_count);
            $display("Total Instructions: %d", instruction_count);
            $display("Execution Time: %.2f ns", cycle_count * 1.0 * CLK_PERIOD);
            $display("Clock Frequency: %.2f MHz", 1000.0 / CLK_PERIOD);
            $display("Predicted Class (DMEM[0]): %0d", dut.u_tcm.u_ram.data_mem[0]);

            $display("\n=== INSTRUCTION PROFILE ===");
            rp_tot = 0;
            for (rp_i = 0; rp_i <= 40; rp_i = rp_i + 1)
                if (rp_fetch[rp_i] > 0) begin
                    $display("%-6s : %0d", rp_name(rp_i), rp_fetch[rp_i]);
                    rp_tot = rp_tot + rp_fetch[rp_i];
                end
            $display("TOTAL PROFILED: %0d", rp_tot);

            $display("\n=== INSTRUCTION MIX (%%) ===");
            for (rp_i = 0; rp_i <= 40; rp_i = rp_i + 1)
                if (rp_fetch[rp_i] > 0)
                    $display("%-6s : %.2f%%", rp_name(rp_i), 100.0 * rp_fetch[rp_i] / instruction_count);
            $display("Memory Ops %%: %.2f%%", 100.0 * (rp_fetch[10] + rp_fetch[11] + rp_fetch[12]
                     + rp_fetch[13] + rp_fetch[14] + rp_fetch[15] + rp_fetch[16] + rp_fetch[17]) / instruction_count);

            $display("\n=== RETIRED INSTRUCTIONS (each counted once at writeback) ===");
            $display("Instructions Retired: %0d   CPI: %.3f", rp_retired, cycle_count * 1.0 / rp_retired);
            for (rp_i = 0; rp_i <= 40; rp_i = rp_i + 1)
                if (rp_ret[rp_i] > 0)
                    $display("%-6s : %0d  (%.2f%%)", rp_name(rp_i), rp_ret[rp_i], 100.0 * rp_ret[rp_i] / rp_retired);
            $display("Memory Ops %%: %.2f%%", 100.0 * (rp_ret[10] + rp_ret[11] + rp_ret[12] + rp_ret[13]
                     + rp_ret[14] + rp_ret[15] + rp_ret[16] + rp_ret[17]) / rp_retired);
        end
    endtask

    // MLIR programs: stop at the single result store
    always @(posedge clk_i) begin
        if (STOP_ON_RESULT_STORE && !rst_cpu_i && !rp_done && (|dut.u_tcm.u_ram.wr1_i)
            && dut.u_tcm.u_ram.addr1_i == 32'h0) begin
            rp_done <= 1'b1;
            program_finished <= 1'b1;       // freezes cycle_count / instruction_count here
            #(CLK_PERIOD * 2);
            rp_report();
            print_memory_contents();
            $finish;
        end
    end

    // paper programs: report when the original completion check fires
    always @(posedge program_finished)
        if (!STOP_ON_RESULT_STORE) rp_report();
