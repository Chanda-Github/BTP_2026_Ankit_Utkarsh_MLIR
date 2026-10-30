// riscv_tcm_top_tb.v for R2 -- the lab's testbench with these changes only (MLIR core flow):
//   1. CLK_PERIOD = 12 ns (paper's R2 clock)
//   2. timeout #(CLK_PERIOD * 100000000): the original constant overflows 32 bits for CLK_PERIOD 14
//   3. $dumpvars commented out (dumping the whole design incl. 2 MB data memory is very slow)
//   4. per-cycle fetch/data trace $display lines commented out (results unchanged)
//   5. report block added before endmodule (paper-style summary + retired-instruction profile);
//      set STOP_ON_RESULT_STORE = 0 there to run the paper's hand-edited programs
`timescale 1ns/1ps   
module riscv_tcm_top_tb();

    
reg [31:0] reg_val;

integer i;

task print_register_file;
        begin
            $display("\n=== REGISTER FILE CONTENTS ===");

for (i = 0; i < 32; i = i + 1) begin
    case (i)
//        0:  reg_val = dut.u_core.u_issue.u_regfile.reg_r0_q;
        1:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r1_q;
        2:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r2_q;
        3:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r3_q;
        4:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r4_q;
        5:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r5_q;
        6:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r6_q;
        7:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r7_q;
        8:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r8_q;
        9:  reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r9_q;
        10: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r10_q;
        11: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r11_q;
        12: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r12_q;
        13: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r13_q;
        14: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r14_q;
        15: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r15_q;
        16: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r16_q;
        17: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r17_q;
        18: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r18_q;
        19: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r19_q;
        20: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r20_q;
        21: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r21_q;
        22: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r22_q;
        23: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r23_q;
        24: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r24_q;
        25: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r25_q;
        26: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r26_q;
        27: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r27_q;
        28: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r28_q;
        29: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r29_q;
        30: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r30_q;
        31: reg_val = dut.u_core.u_issue.u_regfile.REGFILE.reg_r31_q;
        default: reg_val = 32'hDEADBEEF;
    endcase

    $display("x%02d (%-4s): 0x%08h (%0d)", 
             i, get_reg_name(i), reg_val, $signed(reg_val));
end
            
            $display("===============================");
        end
endtask
    
    // Task to print memory contents
    task print_memory_contents;
        begin
            $display("\n=== MEMORY CONTENTS (First 10 Words) ===");            
            for (i = 0; i < 10; i = i + 1) begin
                $display("Addr 0x%08h: 0x%08h (%0d)", 
                         (TCM_MEM_BASE + i*4), dut.u_tcm.u_ram.data_mem[i], $signed(dut.u_tcm.u_ram.data_mem[i]));
            end
            $display("========================================");
            
            $display("\n=== Stack ===");            
            for (i = 0; i < 10; i = i + 1) begin
                $display("Addr 0x%08h: 0x%08h (%0d)", 
                         (77824 - i*4), dut.u_tcm.u_ram.data_mem[19456-i], $signed(dut.u_tcm.u_ram.data_mem[19456-i]));
            end
            $display("========================================");
            
            $display("Addr 0x%08h: 0x%08h (%0d)", 
                         (50000), dut.u_tcm.u_ram.data_mem[12500], $signed(dut.u_tcm.u_ram.data_mem[12500]));
        end
    endtask
    
    // Function to get register names (RISC-V ABI names)
    function [31:0] get_reg_name;
        input [4:0] reg_num;
        begin
            case (reg_num)
                5'd0:  get_reg_name = "zero";
                5'd1:  get_reg_name = "ra  ";
                5'd2:  get_reg_name = "sp  ";
                5'd3:  get_reg_name = "gp  ";
                5'd4:  get_reg_name = "tp  ";
                5'd5:  get_reg_name = "t0  ";
                5'd6:  get_reg_name = "t1  ";
                5'd7:  get_reg_name = "t2  ";
                5'd8:  get_reg_name = "s0  ";
                5'd9:  get_reg_name = "s1  ";
                5'd10: get_reg_name = "a0  ";
                5'd11: get_reg_name = "a1  ";
                5'd12: get_reg_name = "a2  ";
                5'd13: get_reg_name = "a3  ";
                5'd14: get_reg_name = "a4  ";
                5'd15: get_reg_name = "a5  ";
                5'd16: get_reg_name = "a6  ";
                5'd17: get_reg_name = "a7  ";
                5'd18: get_reg_name = "s2  ";
                5'd19: get_reg_name = "s3  ";
                5'd20: get_reg_name = "s4  ";
                5'd21: get_reg_name = "s5  ";
                5'd22: get_reg_name = "s6  ";
                5'd23: get_reg_name = "s7  ";
                5'd24: get_reg_name = "s8  ";
                5'd25: get_reg_name = "s9  ";
                5'd26: get_reg_name = "s10 ";
                5'd27: get_reg_name = "s11 ";
                5'd28: get_reg_name = "t3  ";
                5'd29: get_reg_name = "t4  ";
                5'd30: get_reg_name = "t5  ";
                5'd31: get_reg_name = "t6  ";
                default: get_reg_name = "unk ";
            endcase
        end
    endfunction
    
 
    // Parameters
    parameter BOOT_VECTOR = 32'h00000000;
    parameter CORE_ID = 0;
    parameter TCM_MEM_BASE = 0;
    parameter MEM_CACHE_ADDR_MIN = 0;
    parameter MEM_CACHE_ADDR_MAX = 32'hffffffff;
    parameter CLK_PERIOD = 12; // R2 clock period (ns)
    
    // Clock and Reset
    reg clk_i;
    reg rst_i;
    reg rst_cpu_i;
    
    // AXI Initiator Interface (to external memory)
    reg axi_i_awready_i;
    reg axi_i_wready_i;
    reg axi_i_bvalid_i;
    reg [1:0] axi_i_bresp_i;
    reg axi_i_arready_i;
    reg axi_i_rvalid_i;
    reg [31:0] axi_i_rdata_i;
    reg [1:0] axi_i_rresp_i;
    
    wire axi_i_awvalid_o;
    wire [31:0] axi_i_awaddr_o;
    wire axi_i_wvalid_o;
    wire [31:0] axi_i_wdata_o;
    wire [3:0] axi_i_wstrb_o;
    wire axi_i_bready_o;
    wire axi_i_arvalid_o;
    wire [31:0] axi_i_araddr_o;
    wire axi_i_rready_o;
    
    // AXI Target Interface (for TCM access)
    reg axi_t_awvalid_i;
    reg [31:0] axi_t_awaddr_i;
    reg [3:0] axi_t_awid_i;
    reg [7:0] axi_t_awlen_i;
    reg [1:0] axi_t_awburst_i;
    reg axi_t_wvalid_i;
    reg [31:0] axi_t_wdata_i;
    reg [3:0] axi_t_wstrb_i;
    reg axi_t_wlast_i;
    reg axi_t_bready_i;
    reg axi_t_arvalid_i;
    reg [31:0] axi_t_araddr_i;
    reg [3:0] axi_t_arid_i;
    reg [7:0] axi_t_arlen_i;
    reg [1:0] axi_t_arburst_i;
    reg axi_t_rready_i;
    
    wire axi_t_awready_o;
    wire axi_t_wready_o;
    wire axi_t_bvalid_o;
    wire [1:0] axi_t_bresp_o;
    wire [3:0] axi_t_bid_o;
    wire axi_t_arready_o;
    wire axi_t_rvalid_o;
    wire [31:0] axi_t_rdata_o;
    wire [1:0] axi_t_rresp_o;
    wire [3:0] axi_t_rid_o;
    wire axi_t_rlast_o;
    
    // Interrupt
    reg [31:0] intr_i;
    
    // Timing measurement variables
    integer cycle_count;
    real start_time;
    real end_time;
    real execution_time;
    
    // Control variables
    reg program_finished;
    reg [31:0] last_pc;
    reg [31:0] pc_stable_count;
    reg [31:0] instruction_count;
    
    // DUT instantiation
    riscv_tcm_top #(
        .BOOT_VECTOR(BOOT_VECTOR),
        .CORE_ID(CORE_ID),
        .TCM_MEM_BASE(TCM_MEM_BASE),
        .MEM_CACHE_ADDR_MIN(MEM_CACHE_ADDR_MIN),
        .MEM_CACHE_ADDR_MAX(MEM_CACHE_ADDR_MAX)
    ) dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .rst_cpu_i(rst_cpu_i),
        .axi_i_awready_i(axi_i_awready_i),
        .axi_i_wready_i(axi_i_wready_i),
        .axi_i_bvalid_i(axi_i_bvalid_i),
        .axi_i_bresp_i(axi_i_bresp_i),
        .axi_i_arready_i(axi_i_arready_i),
        .axi_i_rvalid_i(axi_i_rvalid_i),
        .axi_i_rdata_i(axi_i_rdata_i),
        .axi_i_rresp_i(axi_i_rresp_i),
        .axi_t_awvalid_i(axi_t_awvalid_i),
        .axi_t_awaddr_i(axi_t_awaddr_i),
        .axi_t_awid_i(axi_t_awid_i),
        .axi_t_awlen_i(axi_t_awlen_i),
        .axi_t_awburst_i(axi_t_awburst_i),
        .axi_t_wvalid_i(axi_t_wvalid_i),
        .axi_t_wdata_i(axi_t_wdata_i),
        .axi_t_wstrb_i(axi_t_wstrb_i),
        .axi_t_wlast_i(axi_t_wlast_i),
        .axi_t_bready_i(axi_t_bready_i),
        .axi_t_arvalid_i(axi_t_arvalid_i),
        .axi_t_araddr_i(axi_t_araddr_i),
        .axi_t_arid_i(axi_t_arid_i),
        .axi_t_arlen_i(axi_t_arlen_i),
        .axi_t_arburst_i(axi_t_arburst_i),
        .axi_t_rready_i(axi_t_rready_i),
        .intr_i(intr_i),
        .axi_i_awvalid_o(axi_i_awvalid_o),
        .axi_i_awaddr_o(axi_i_awaddr_o),
        .axi_i_wvalid_o(axi_i_wvalid_o),
        .axi_i_wdata_o(axi_i_wdata_o),
        .axi_i_wstrb_o(axi_i_wstrb_o),
        .axi_i_bready_o(axi_i_bready_o),
        .axi_i_arvalid_o(axi_i_arvalid_o),
        .axi_i_araddr_o(axi_i_araddr_o),
        .axi_i_rready_o(axi_i_rready_o),
        .axi_t_awready_o(axi_t_awready_o),
        .axi_t_wready_o(axi_t_wready_o),
        .axi_t_bvalid_o(axi_t_bvalid_o),
        .axi_t_bresp_o(axi_t_bresp_o),
        .axi_t_bid_o(axi_t_bid_o),
        .axi_t_arready_o(axi_t_arready_o),
        .axi_t_rvalid_o(axi_t_rvalid_o),
        .axi_t_rdata_o(axi_t_rdata_o),
        .axi_t_rresp_o(axi_t_rresp_o),
        .axi_t_rid_o(axi_t_rid_o),
        .axi_t_rlast_o(axi_t_rlast_o)
    );
    
    // Clock generation
    always #(CLK_PERIOD/2) clk_i = ~clk_i;
    
    // AXI Initiator Interface Mock (for external memory accesses)
    always @(posedge clk_i) begin
        if (rst_i) begin
            axi_i_awready_i <= 1'b0;
            axi_i_wready_i <= 1'b0;
            axi_i_bvalid_i <= 1'b0;
            axi_i_bresp_i <= 2'b00;
            axi_i_arready_i <= 1'b0;
            axi_i_rvalid_i <= 1'b0;
            axi_i_rdata_i <= 32'h0;
            axi_i_rresp_i <= 2'b00;
        end else begin
            // Simple AXI slave response (always ready, no errors)
            axi_i_awready_i <= axi_i_awvalid_o;
            axi_i_wready_i <= axi_i_wvalid_o;
            axi_i_bvalid_i <= axi_i_awvalid_o && axi_i_wvalid_o;
            axi_i_bresp_i <= 2'b00; // OKAY response
            axi_i_arready_i <= axi_i_arvalid_o;
            axi_i_rvalid_i <= axi_i_arvalid_o;
            axi_i_rdata_i <= 32'hDEADBEEF; // Dummy data
            axi_i_rresp_i <= 2'b00; // OKAY response
        end
    end
    
    // Cycle counter
    always @(posedge clk_i) begin
        if (rst_cpu_i)
            cycle_count <= 0;
        else if (!program_finished)
            cycle_count <= cycle_count + 1;
    end
    
    // Program completion detection
    // Monitor PC changes to detect when program execution stops
    always @(posedge clk_i) begin
        if (rst_cpu_i) begin
            last_pc <= 32'h0;
            pc_stable_count <= 0;
            program_finished <= 1'b0;
            instruction_count <= 0;
        end else begin
            // Access PC from the core (you may need to adjust this path based on your hierarchy)
            if (dut.ifetch_pc_w == last_pc) begin
                pc_stable_count <= pc_stable_count + 1;
                // If PC hasn't changed for 100 cycles, assume program finished
                if (pc_stable_count >= 100 && !program_finished) begin
                    program_finished <= 1'b1;
                    end_time = $realtime;
                    execution_time = end_time - start_time;
                    
                    $display("\n=== PROGRAM EXECUTION COMPLETED ===");
                    $display("Total Clock Cycles: %d", cycle_count);
                    $display("Total Instructions: %d", instruction_count);
                    $display("Execution Time: %.2f ns", execution_time);
                    $display("Clock Frequency: %.2f MHz", 1000.0/CLK_PERIOD);
//                    $display("Average CPI: %.2f", real'(cycle_count)/real'(instruction_count));
                    $display("Final PC: 0x%08h", dut.ifetch_pc_w);
                    
                     // Print register file contents
                    print_register_file();
                    
                    // Print first 10 memory locations
                    print_memory_contents();
                    
                    $display("=====================================\n");
                    
                    #(CLK_PERIOD * 10); // Wait a few more cycles
                    $finish;
                end
            end else begin
                last_pc <= dut.ifetch_pc_w;
                pc_stable_count <= 0;
                if (dut.ifetch_valid_w && dut.ifetch_accept_w) begin
                    instruction_count <= instruction_count + 1;
                end
            end
        end
    end
    
    // Instruction monitoring (optional - for debugging)
    always @(posedge clk_i) begin
        if (!rst_cpu_i && dut.ifetch_valid_w && dut.ifetch_accept_w) begin
            // $display("Cycle %d: PC=0x%08h, Instruction=0x%08h",
            //          cycle_count, dut.ifetch_pc_w, dut.ifetch_inst_w);
        end
    end
    
    // Memory access monitoring (optional - for debugging)
    always @(posedge clk_i) begin
        if (!rst_cpu_i && dut.dport_ack_w) begin
            if (dut.dport_rd_w) begin
                // $display("Cycle %d: Data Read - Addr=0x%08h, Data=0x%08h",
                //          cycle_count, dut.dport_addr_w, dut.dport_data_rd_w);
            end
            if (|dut.dport_wr_w) begin
                // $display("Cycle %d: Data Write - Addr=0x%08h, Data=0x%08h, Strobe=0x%h",
                //          cycle_count, dut.dport_addr_w, dut.dport_data_wr_w, dut.dport_wr_w);
            end
        end
    end
    
    // Test sequence
    initial begin
        // Initialize signals
        clk_i = 1'b0;
        rst_i = 1'b1;
        rst_cpu_i = 1'b1;
        intr_i = 32'h0;
        
        // Initialize AXI Target interface (no external access initially)
        axi_t_awvalid_i = 1'b0;
        axi_t_awaddr_i = 32'h0;
        axi_t_awid_i = 4'h0;
        axi_t_awlen_i = 8'h0;
        axi_t_awburst_i = 2'b01;
        axi_t_wvalid_i = 1'b0;
        axi_t_wdata_i = 32'h0;
        axi_t_wstrb_i = 4'h0;
        axi_t_wlast_i = 1'b0;
        axi_t_bready_i = 1'b1;
        axi_t_arvalid_i = 1'b0;
        axi_t_araddr_i = 32'h0;
        axi_t_arid_i = 4'h0;
        axi_t_arlen_i = 8'h0;
        axi_t_arburst_i = 2'b01;
        axi_t_rready_i = 1'b1;
        
        // Initialize timing
        cycle_count = 0;
        program_finished = 1'b0;
        last_pc = 32'h0;
        pc_stable_count = 0;
        instruction_count = 0;
        
        $display("=== Starting RISC-V TCM Testbench ===");
        $display("Boot Vector: 0x%08h", BOOT_VECTOR);
        $display("Core ID: %d", CORE_ID);
        $display("TCM Base: 0x%08h", TCM_MEM_BASE);
        $display("Clock Period: %d ns", CLK_PERIOD);
        $display("=====================================");
        
        // Reset sequence
        repeat(10) @(posedge clk_i);
        rst_i = 1'b0;
        repeat(5) @(posedge clk_i);
        rst_cpu_i = 1'b0;
        
        start_time = $realtime;
        
        $display("CPU released from reset at time %.2f ns", start_time);
        $display("Starting program execution...\n");
        
        // Wait for program completion (handled by always blocks above)
        wait(program_finished);
        
        $display("Testbench completed successfully!");
    end
    
    // Timeout protection
    initial begin
        #(CLK_PERIOD * 100000000); // timeout after 100 million cycles
        if (!program_finished) begin
            $display("\n=== TIMEOUT REACHED ===");
            $display("Total Clock Cycles: %d", cycle_count);
            $display("Total Instructions: %d", instruction_count);
            $display("Current PC: 0x%08h", dut.ifetch_pc_w);
            $display("Program may be stuck in infinite loop or waiting for interrupt");
            $display("=======================\n");
            
             // Print register file contents
                    print_register_file();
                    
                    // Print first 10 memory locations
                    print_memory_contents();
                    
            $finish;
        end
    end
    
    // Generate VCD dump for waveform analysis
    initial begin
        // $dumpfile("riscv_tcm_tb.vcd");
        // $dumpvars(0, riscv_tcm_top_tb);
    end

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

endmodule