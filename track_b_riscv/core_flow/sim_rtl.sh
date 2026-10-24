#!/usr/bin/env bash
# sim_rtl.sh <codalab_repo_root> <r1|r2> <mem_dir>
#   Runs the generated memoryi.mem / memoryd.mem on the lab's own Verilog with Icarus Verilog
#   (same testbench riscv_tcm_top_tb.v as in Vivado, unchanged):
#     r1 = new-RISCV/rv32im_2_meminc  (full RV32IM core)
#     r2 = new-RISCV/rv32im_2_mod3_2  (reduced core)
#   Prints the cycle count and the result word (DMEM address 0) and compares it with
#   <mem_dir>/../expected.json.  The full per-instruction trace goes to <mem_dir>/rtl_sim.log.
set -euo pipefail
ROOT=${1:?usage: sim_rtl.sh <codalab_repo_root> <r1|r2> <mem_dir>}
CORE=${2:?}
MEM=$(cd "${3:?}" && pwd)
case $CORE in
  r1) P=rv32im_2_meminc ;;
  r2) P=rv32im_2_mod3_2 ;;
  *) echo "core must be r1 or r2"; exit 1 ;;
esac
BUILD=$(mktemp -d)
SRC=$(find "$ROOT/new-RISCV/$P" -path "*sources_1*" -name "*.v" \
      ! -name glbl.v ! -name post_synth_tb.v ! -name riscv_tcm_top_tb.v | sort)
# Testbench: the lab's riscv_tcm_top_tb.v with only two speed changes for Icarus --
# no VCD dump of the whole design (incl. 2 MB data memory) and no per-cycle trace prints
# (FULL_TRACE=1 keeps the trace), and a timeout of MAX_CYCLES (default 20M) instead of 1e9+.
# Reset, end detection and result printing are unchanged.
TB=$(find "$ROOT/new-RISCV/$P" -path "*sim_1/new/riscv_tcm_top_tb.v" | head -1)
if [ "${FULL_TRACE:-0}" = 1 ]; then
    sed -e '/\$dumpfile\|\$dumpvars/d' -e "s/#(CLK_PERIOD \* [0-9]*)/#(CLK_PERIOD * ${MAX_CYCLES:-20000000})/" "$TB" > "$BUILD/tb.v"
else
    sed -e '/\$dumpfile\|\$dumpvars/d' -e "s/#(CLK_PERIOD \* [0-9]*)/#(CLK_PERIOD * ${MAX_CYCLES:-20000000})/" \
        -e 's/\$display("Cycle %d:/if (0) $display("Cycle %d:/' "$TB" > "$BUILD/tb.v"
fi
# End marker: the generated program stores its result to DMEM address 0 exactly once, as its last
# action (the core never holds the PC still, so the testbench's "PC stable for 100 cycles" check
# never fires -- every trap returns to the boot vector). This block, added before 'endmodule',
# stops the run 5 cycles after that store and prints the same summary. Core RTL is untouched.
# RESULT_STOP=0: do not stop, log every store to DMEM[0] (for programs that store it repeatedly).
python3 - "$BUILD/tb.v" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
block = """
    // ---- added by sim_rtl.sh: end of a generated program = its single store to DMEM[0] ----
    always @(posedge clk_i)
        if (!rst_cpu_i && (|dut.u_tcm.u_ram.wr1_i) && dut.u_tcm.u_ram.addr1_i == 32'h0 && !`RESULT_STOP)
            $display("DMEM0_WRITE cycle=%0d value=%0d", cycle_count, dut.u_tcm.u_ram.data1_i);
    reg [31:0] result_store_cycle;
    initial result_store_cycle = 0;
    always @(posedge clk_i) begin
        if (!rst_cpu_i && (|dut.u_tcm.u_ram.wr1_i) && dut.u_tcm.u_ram.addr1_i == 32'h0
            && result_store_cycle == 0 && `RESULT_STOP) begin
            result_store_cycle <= cycle_count;
            $display("\\n=== RESULT STORED (DMEM[0] = %0d) ===", dut.u_tcm.u_ram.data1_i);
            $display("Result Store Cycle: %0d", cycle_count);
            $display("Instructions Fetched: %0d", instruction_count);
            #(CLK_PERIOD * 5);
            print_memory_contents();
            $finish;
        end
    end
"""
i = s.rindex("endmodule")
open(p, "w").write(s[:i] + block + s[i:])
PYEOF
SRC="$SRC $BUILD/tb.v"
INC=$(for f in $SRC; do dirname "$f"; done | sort -u | sed 's/^/-I/')
iverilog -g2012 -s riscv_tcm_top_tb -DRESULT_STOP=${RESULT_STOP:-1} $INC -o "$BUILD/sim" $SRC
( cd "$MEM" && vvp -n "$BUILD/sim" > "$MEM/rtl_sim.log" 2>&1 ) || true
rm -rf "$BUILD"

cycles=$(grep -m1 "Result Store Cycle" "$MEM/rtl_sim.log" | awk '{print $NF}')
insns=$(grep -m1 "Instructions Fetched" "$MEM/rtl_sim.log" | awk '{print $NF}')
result=$(grep -m1 "Addr 0x00000000:" "$MEM/rtl_sim.log" | sed -E 's/.*\(([-0-9]+)\).*/\1/')
expected=$(python3 -c "import json;print(json.load(open('$MEM/../expected.json'))['expected_result'])")
if [ -z "$cycles" ]; then
    echo "[rtl] $CORE: no result store within MAX_CYCLES -- see $MEM/rtl_sim.log"; exit 1
fi
status=PASS; [ "$result" = "$expected" ] || status=FAIL
echo "[rtl] $CORE ($P): result=$result expected=$expected $status | cycles=$cycles instructions=$insns"
[ $status = PASS ]
