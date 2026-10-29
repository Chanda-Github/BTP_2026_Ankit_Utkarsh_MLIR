#!/usr/bin/env bash
# sim_rtl.sh <codalab_repo_root> <r1|r2> <mem_dir>
#   Runs memoryi.mem / memoryd.mem (in <mem_dir>) on the lab's own Verilog:
#     r1 = new-RISCV/rv32im_2_meminc  (full RV32IM core)
#     r2 = new-RISCV/rv32im_2_mod3_2  (reduced core)
#   with the lab's testbench riscv_tcm_top_tb.v (patched only as described below).
#   Prints the predicted class (DMEM[0]) and the cycle count, and compares the class with
#   <mem_dir>/../expected.json if present. Simulator output goes to <mem_dir>/rtl_sim.log.
#
# Simulator: Verilator if installed (about 1.3M cycles/s), else Icarus Verilog (about 4.5k
# cycles/s); force with SIM=icarus|verilator. Both are cycle-accurate on the same RTL and give
# identical cycle counts. Each core is compiled once and cached in ~/.cache/tm_rtl_sim/.
#
# Environment options (passed to the simulation as plusargs, no recompilation):
#   MAX_CYCLES=<n>      timeout (default 20000000)
#   FULL_TRACE=1        keep the testbench's per-cycle fetch/data trace
#   RESTART_STOP=1      stop when the program jumps back to PC 0 (programs ending in ret/trap,
#                       e.g. the paper's hand-edited ones); reports the last DMEM[0] store cycle
#   RESULT_STOP=0       never stop on a DMEM[0] store; log each one instead
#   DUMP_ADDR=<byte address> DUMP_WORDS=<n>   print n data-memory words at the end (votes[])
#   STORE_TRACE=1       print every data-TCM write ("ST <word index> <strobe> <data>")
#
# Testbench patch (copy only; core RTL untouched):
#   - no VCD dump of the whole design (incl. 2 MB data memory); per-cycle trace off by default
#   - timeout from MAX_CYCLES instead of 1e9+ cycles
#   - end marker: the generated programs store the class to DMEM[0] exactly once, as their last
#     action; the run stops 5 cycles later and reports that cycle. (With this testbench copy the
#     "PC stable for 100 cycles" check does not fire under Icarus/Verilator: a self-jump keeps the
#     prefetcher moving and ret/ecall/ebreak return to the boot vector.)
set -euo pipefail
ROOT=${1:?usage: sim_rtl.sh <codalab_repo_root> <r1|r2> <mem_dir>}
CORE=${2:?}
MEM=$(cd "${3:?}" && pwd)
case $CORE in
  r1) P=rv32im_2_meminc ;;
  r2) P=rv32im_2_mod3_2 ;;
  *) echo "core must be r1 or r2"; exit 1 ;;
esac
SIM=${SIM:-$(command -v verilator >/dev/null && echo verilator || echo icarus)}

SRC=$(find "$ROOT/new-RISCV/$P" -path "*sources_1*" -name "*.v" \
      ! -name glbl.v ! -name post_synth_tb.v ! -name riscv_tcm_top_tb.v | sort)
TB=$(find "$ROOT/new-RISCV/$P" -path "*sim_1/new/riscv_tcm_top_tb.v" | head -1)
INC=$(for f in $SRC; do dirname "$f"; done | sort -u | sed 's/^/-I/')

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
python3 - "$TB" "$TMP/tb.v" <<'PYEOF'
import re, sys
s = open(sys.argv[1]).read()
s = "\n".join(l for l in s.splitlines() if "$dumpfile" not in l and "$dumpvars" not in l)
s = s.replace('$display("Cycle %d:', 'if (opt_trace) $display("Cycle %d:')
s = re.sub(r"#\(CLK_PERIOD \* \d+\);", "#1; #(CLK_PERIOD * opt_max_cycles);", s)
head = """
    // ---- added by sim_rtl.sh: run-time options (plusargs) ----
    reg        opt_trace, opt_result_stop, opt_restart_stop, opt_store_trace;
    reg [31:0] opt_dump_addr, opt_dump_words;
    reg [63:0] opt_max_cycles;
    initial begin
        opt_trace        = $test$plusargs("TRACE");
        opt_store_trace  = $test$plusargs("STORE_TRACE");
        opt_restart_stop = $test$plusargs("RESTART_STOP");
        opt_result_stop  = !opt_restart_stop && !$test$plusargs("NO_RESULT_STOP");
        if (!$value$plusargs("DUMP_ADDR=%d", opt_dump_addr))   opt_dump_addr  = 0;
        if (!$value$plusargs("DUMP_WORDS=%d", opt_dump_words)) opt_dump_words = 0;
        if (!$value$plusargs("MAX_CYCLES=%d", opt_max_cycles)) opt_max_cycles = 20000000;
    end
"""
foot = """
    // ---- added by sim_rtl.sh ----
    task dump_region;
        integer di;
        begin
            for (di = 0; di < opt_dump_words; di = di + 1)
                $display("DUMP addr=%0d value=%0d", opt_dump_addr + 4*di,
                         $signed(dut.u_tcm.u_ram.data_mem[(opt_dump_addr >> 2) + di]));
        end
    endtask

    // STORE_TRACE: every write into the data TCM (word index, byte strobe, data)
    always @(posedge clk_i)
        if (opt_store_trace && !rst_cpu_i && (|dut.u_tcm.u_ram.wr1_i))
            $display("ST %0d %0h %0h", dut.u_tcm.u_ram.addr1_i, dut.u_tcm.u_ram.wr1_i, dut.u_tcm.u_ram.data1_i);

    // End marker of a generated program: its single store to DMEM[0].
    reg [31:0] result_store_cycle;
    reg [31:0] last_dmem0_store;
    reg        left_boot;
    initial begin result_store_cycle = 0; last_dmem0_store = 0; left_boot = 0; end
    always @(posedge clk_i) begin
        if (!rst_cpu_i && (|dut.u_tcm.u_ram.wr1_i) && dut.u_tcm.u_ram.addr1_i == 32'h0) begin
            last_dmem0_store <= cycle_count;
            if (!opt_result_stop && !opt_restart_stop)
                $display("DMEM0_WRITE cycle=%0d value=%0d", cycle_count, dut.u_tcm.u_ram.data1_i);
            if (opt_result_stop && result_store_cycle == 0) begin
                result_store_cycle <= cycle_count;
                $display("\\n=== RESULT STORED (DMEM[0] = %0d) ===", dut.u_tcm.u_ram.data1_i);
                $display("Result Store Cycle: %0d", cycle_count);
                $display("Instructions Fetched: %0d", instruction_count);
                #(CLK_PERIOD * 5);
                print_memory_contents();
                dump_region();
                $finish;
            end
        end
    end

    // RESTART_STOP: programs that end with ret/trap jump back to the boot vector (PC 0).
    always @(posedge clk_i) begin
        if (!rst_cpu_i && dut.ifetch_valid_w && dut.ifetch_accept_w) begin
            if (dut.ifetch_pc_w >= 32'h40) left_boot <= 1'b1;
            if (opt_restart_stop && left_boot && dut.ifetch_pc_w == 32'h0) begin
                $display("\\n=== PROGRAM RESTART (end of first pass) ===");
                $display("Result Store Cycle: %0d", last_dmem0_store);
                $display("Restart Cycle: %0d", cycle_count);
                $display("Instructions Fetched: %0d", instruction_count);
                print_memory_contents();
                dump_region();
                $finish;
            end
        end
    end
"""
m = re.search(r"module\s+riscv_tcm_top_tb\s*\(\s*\)\s*;", s)
s = s[:m.end()] + head + s[m.end():]
i = s.rindex("endmodule")
s = s[:i] + foot + s[i:]
open(sys.argv[2], "w").write(s)
PYEOF

# ---- build once per (simulator, sources, patched testbench); cache the executable
KEY=$( (echo "$SIM"; if [ "$SIM" = verilator ]; then verilator --version; else iverilog -V 2>&1 | head -1; fi; cat $SRC "$TMP/tb.v") | md5sum | cut -c1-16)
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/tm_rtl_sim/$P-$SIM-$KEY
if [ ! -x "$CACHE/sim" ]; then
    mkdir -p "$(dirname "$CACHE")"
    B=$(mktemp -d "$(dirname "$CACHE")/build.XXXX")
    if [ "$SIM" = verilator ]; then
        # Verilator defines the macro 'verilator', which enables the cores' debug-only disassembly
        # blocks (riscv_trace_sim, get_regname_str). R2 removed the instruction defines those blocks
        # print, so they do not compile there; Vivado and Icarus never compile them. Build from a
        # copy with only those debug blocks switched off.
        mkdir -p "$TMP/src"
        for f in $SRC; do sed 's/`ifdef verilator/`ifdef TM_UNUSED_TRACE/' "$f" > "$TMP/src/$(basename "$f")"; done
        VSRC=$(for f in $SRC; do echo "$TMP/src/$(basename "$f")"; done)
        verilator --binary --timing -O3 -j "$(nproc)" -Wno-fatal -Wno-lint -Wno-style \
            --top-module riscv_tcm_top_tb -I"$TMP/src" $VSRC "$TMP/tb.v" --Mdir "$B/obj" -o sim > "$B/build.log" 2>&1 \
            || { echo "[rtl] verilator build failed: $B/build.log"; exit 1; }
        cp "$B/obj/sim" "$B/sim"
        rm -rf "$B/obj"
    else
        iverilog -g2012 -s riscv_tcm_top_tb $INC -o "$B/sim" $SRC "$TMP/tb.v"
    fi
    mv -T "$B" "$CACHE" 2>/dev/null || rm -rf "$B"     # another run may have finished first
fi

# Some hand-made memory files end without a final newline. Verilator's $readmemh then drops the
# last word (it reads as 0), which silently corrupts the image -- e.g. Tests/statlog/50/memoryd.mem,
# whose last word is a clause_output pointer. Add the newline if it is missing.
for f in "$MEM/memoryi.mem" "$MEM/memoryd.mem"; do
    [ -s "$f" ] && [ "$(tail -c 1 "$f" | od -An -c | tr -d ' ')" != '\n' ] && echo >> "$f"
done

ARGS="+MAX_CYCLES=${MAX_CYCLES:-20000000}"
[ "${FULL_TRACE:-0}" = 1 ]   && ARGS="$ARGS +TRACE"
[ "${STORE_TRACE:-0}" = 1 ]  && ARGS="$ARGS +STORE_TRACE"
[ "${RESTART_STOP:-0}" = 1 ] && ARGS="$ARGS +RESTART_STOP"
[ "${RESULT_STOP:-1}" = 0 ]  && ARGS="$ARGS +NO_RESULT_STOP"
[ -n "${DUMP_ADDR:-}" ]      && ARGS="$ARGS +DUMP_ADDR=$DUMP_ADDR +DUMP_WORDS=${DUMP_WORDS:-0}"
if [ "$SIM" = verilator ]; then
    ( cd "$MEM" && "$CACHE/sim" $ARGS > "$MEM/rtl_sim.log" 2>&1 ) || true
else
    ( cd "$MEM" && vvp -n "$CACHE/sim" $ARGS > "$MEM/rtl_sim.log" 2>&1 ) || true
fi

cycles=$(grep -m1 "Result Store Cycle" "$MEM/rtl_sim.log" | awk '{print $NF}')
insns=$(grep -m1 "Instructions Fetched" "$MEM/rtl_sim.log" | awk '{print $NF}')
result=$(grep -m1 "Addr 0x00000000:" "$MEM/rtl_sim.log" | sed -E 's/.*\(([-0-9]+)\).*/\1/')
expected=$(python3 -c "import json;print(json.load(open('$MEM/../expected.json'))['expected_result'])" 2>/dev/null || echo "?")
if [ -z "$cycles" ]; then
    echo "[rtl] $CORE: no result store within MAX_CYCLES -- see $MEM/rtl_sim.log"; exit 1
fi
status=PASS
if [ "$expected" = "?" ]; then status=DONE; elif [ "$result" != "$expected" ]; then status=FAIL; fi
echo "[rtl] $CORE ($P, $SIM): result=$result expected=$expected $status | cycles=$cycles instructions=$insns"
[ $status != FAIL ]
