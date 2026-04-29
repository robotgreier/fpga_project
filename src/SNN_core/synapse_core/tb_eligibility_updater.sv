`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/13/2026
// Design Name:
// Module Name: tb_eligibility_updater
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Testbench for eligibility_updater -- covers learning-mode
//              disable, LTP/LTD updates, timer windows, decay, and clamping.
//
// Dependencies: eligibility_updater.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module tb_eligibility_updater ();

    // --------------------------------------------------------------------------
    // Parameters matching dut_on / dut_off defaults
    // --------------------------------------------------------------------------
    localparam int T_PRE       = 2;
    localparam int T_POST      = 2;
    localparam int TAU_E_SHIFT = 2;
    localparam int DW_POS      = 16;
    localparam int DW_NEG      = 64;
    localparam int MAX_E_TRACE = 255;
    localparam int MIN_E_TRACE = -256;

    // --------------------------------------------------------------------------
    // Shared DUT signals
    // --------------------------------------------------------------------------
    logic clk;
    logic rst;
    logic run  = 1'b1;  // always enabled: unit test, not gating
    logic pre_spk;
    logic post_spk;

    // Output per instance
    logic signed [8:0] elig_off;    // LEARNING_MODE = 0  (always zero)
    logic signed [8:0] elig_on;     // LEARNING_MODE = 1  (default params)
    logic signed [8:0] elig_clamp;  // LEARNING_MODE = 1  (large DW for clamp tests)

    // --------------------------------------------------------------------------
    // DUT instantiation -- one per configuration
    // --------------------------------------------------------------------------
    eligibility_updater #(
        .LEARNING_MODE(0)
    ) dut_off (
        .clk       (clk),
        .run       (run),
        .pre_spk   (pre_spk),
        .post_spk  (post_spk),
        .rst       (rst),
        .elig_trace(elig_off)
    );

    eligibility_updater #(
        .T_PRE      (T_PRE),
        .T_POST     (T_POST),
        .TAU_E_SHIFT(TAU_E_SHIFT),
        .DW_POS     (DW_POS),
        .DW_NEG     (DW_NEG),
        .LEARNING_MODE(1),
        .MAX_E_TRACE(MAX_E_TRACE),
        .MIN_E_TRACE(MIN_E_TRACE)
    ) dut_on (
        .clk       (clk),
        .run       (run),
        .pre_spk   (pre_spk),
        .post_spk  (post_spk),
        .rst       (rst),
        .elig_trace(elig_on)
    );

    // Large DW_POS / DW_NEG so a single spike pair saturates the clamp
    eligibility_updater #(
        .DW_POS      (500),
        .DW_NEG      (500),
        .LEARNING_MODE(1)
    ) dut_clamp (
        .clk       (clk),
        .run       (run),
        .pre_spk   (pre_spk),
        .post_spk  (post_spk),
        .rst       (rst),
        .elig_trace(elig_clamp)
    );

    // --------------------------------------------------------------------------
    // Clock generation -- 10 ns period (100 MHz)
    // --------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------------------------------
    // Pass / fail counters
    // --------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // --------------------------------------------------------------------------
    // Helper task: drive spike inputs for one clock cycle
    // --------------------------------------------------------------------------
    task automatic apply_spikes(input logic pre_val, post_val);
        @(negedge clk);
        pre_spk  = pre_val;
        post_spk = post_val;
        rst      = 1'b0;
        @(posedge clk);
        #1;  // let outputs settle
    endtask

    // --------------------------------------------------------------------------
    // Helper task: idle (no spikes) for N clock cycles
    // --------------------------------------------------------------------------
    task automatic idle_cycles(input int n);
        repeat (n) apply_spikes(1'b0, 1'b0);
    endtask

    // --------------------------------------------------------------------------
    // Helper task: assert reset for two cycles then release
    // --------------------------------------------------------------------------
    task automatic do_rst();
        @(negedge clk);
        rst      = 1'b1;
        pre_spk  = 1'b0;
        post_spk = 1'b0;
        @(posedge clk); #1;
        @(negedge clk); @(posedge clk); #1;
        rst = 1'b0;
    endtask

    // --------------------------------------------------------------------------
    // Assertion helper: check one output value, print PASS / FAIL
    // --------------------------------------------------------------------------
    task automatic check(
        input string             label,
        input logic signed [8:0] got,
        input logic signed [8:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %s : elig_trace = %0d", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s : got %0d, expected %0d", label, got, expected);
            fail_count++;
        end
    endtask

    // --------------------------------------------------------------------------
    // Continuous monitor: show all outputs on every posedge
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        #1;
        $display("[%0t ns]  pre=%b post=%b | off=%0d  on=%0d  clamp=%0d",
                 $time, pre_spk, post_spk, elig_off, elig_on, elig_clamp);
    end

    // --------------------------------------------------------------------------
    // Stimulus
    // --------------------------------------------------------------------------
    initial begin
        // ----- Initialise -----
        rst      = 1'b1;
        pre_spk  = 1'b0;
        post_spk = 1'b0;

        // ==================================================================
        // TEST 0: Reset -- elig_trace must be zero while rst is asserted
        // ==================================================================
        $display("\n[%0t] TEST 0: Reset -- elig_trace must be zero during rst", $time);
        @(negedge clk); @(posedge clk); #1;
        @(negedge clk); @(posedge clk); #1;
        check("off   | rst=1", elig_off,   9'sd0);
        check("on    | rst=1", elig_on,    9'sd0);
        check("clamp | rst=1", elig_clamp, 9'sd0);
        @(negedge clk);
        rst = 1'b0;
        idle_cycles(1);

        // ==================================================================
        // TEST 1: No-learning mode -- elig_trace must always be zero
        //
        // With LEARNING_MODE=0 the combinational path forces e_comb=0, so
        // no spike pattern can change the registered trace.
        // ==================================================================
        $display("\n[%0t] TEST 1: No-learning mode -- elig_trace always zero", $time);
        apply_spikes(1'b1, 1'b0);
        check("off   | pre=1, post=0", elig_off, 9'sd0);
        apply_spikes(1'b0, 1'b1);
        check("off   | LTP attempt (post after pre)", elig_off, 9'sd0);
        apply_spikes(1'b1, 1'b1);
        check("off   | pre=1, post=1 simultaneous", elig_off, 9'sd0);
        idle_cycles(1);

        // ==================================================================
        // TEST 2: LTP -- post fires 1 cycle after pre
        //
        // pre fires  → pre_timer=0,  e_trace unchanged (no post history)
        // post fires → pre_timer=0 ≥ 0 → LTP:
        //   e_comb = 0 + DW_POS(16) − (16 >>> TAU_E_SHIFT(2)) = 16 − 4 = 12
        // ==================================================================
        $display("\n[%0t] TEST 2: LTP -- post fires 1 cycle after pre", $time);
        do_rst();
        apply_spikes(1'b1, 1'b0);               // pre edge; no post history
        check("on    | pre spike alone",         elig_on, 9'sd0);
        apply_spikes(1'b0, 1'b1);               // post edge 1 cycle later
        check("on    | LTP: post 1 cycle after pre", elig_on, 9'sd12);
        idle_cycles(2);

        // ==================================================================
        // TEST 3: LTD -- pre fires 1 cycle after post
        //
        // post fires → post_timer=0, e_trace unchanged (no pre history)
        // pre fires  → post_timer=0 ≥ 0 → LTD:
        //   e_comb = 0 − DW_NEG(64) − (−64 >>> 2) = −64 + 16 = −48
        // ==================================================================
        $display("\n[%0t] TEST 3: LTD -- pre fires 1 cycle after post", $time);
        do_rst();
        apply_spikes(1'b0, 1'b1);               // post edge; no pre history
        check("on    | post spike alone",        elig_on, 9'sd0);
        apply_spikes(1'b1, 1'b0);               // pre edge 1 cycle later
        check("on    | LTD: pre 1 cycle after post", elig_on, -9'sd48);
        idle_cycles(2);

        // ==================================================================
        // TEST 4: Decay -- trace decays exponentially toward zero
        //
        // Each idle cycle applies: e_next = e_comb − (e_comb >>> TAU_E_SHIFT)
        //   12 → 12 − 3 = 9  → 9 − 2 = 7  → 7 − 1 = 6
        // ==================================================================
        $display("\n[%0t] TEST 4: Decay -- trace decays toward zero", $time);
        do_rst();
        apply_spikes(1'b1, 1'b0);  // build trace via LTP (12)
        apply_spikes(1'b0, 1'b1);
        idle_cycles(1);
        check("on    | decay cycle 1: 12 → 9",  elig_on, 9'sd9);
        idle_cycles(1);
        check("on    | decay cycle 2:  9 → 7",  elig_on, 9'sd7);
        idle_cycles(1);
        check("on    | decay cycle 3:  7 → 6",  elig_on, 9'sd6);
        idle_cycles(2);

        // ==================================================================
        // TEST 5: No STDP without prior spike in window
        //
        // post alone (pre_timer = DISABLED) → no LTP
        // After the post timer expires, pre alone (post_timer = DISABLED) → no LTD
        // ==================================================================
        $display("\n[%0t] TEST 5: No STDP without spike history", $time);
        do_rst();
        apply_spikes(1'b0, 1'b1);  // post fires; pre_timer = -1 → no LTP
        check("on    | post alone, no prior pre → no LTP", elig_on, 9'sd0);
        idle_cycles(T_POST + 3);   // wait for post_timer to expire (DISABLED)
        apply_spikes(1'b1, 1'b0);  // pre fires; post_timer = -1 → no LTD
        check("on    | pre alone, no prior post → no LTD", elig_on, 9'sd0);
        idle_cycles(2);

        // ==================================================================
        // TEST 6: LTP window edge -- post fires T_PRE+2 cycles after pre
        //
        // Timer progression: 0 → 1 → 2 → 3 (T_PRE+1); at posedge where
        // post fires pre_timer = T_PRE+1 = 3 ≥ 0 → still inside window.
        //   e_comb = 0 + 16 − 4 = 12
        // ==================================================================
        $display("\n[%0t] TEST 6: LTP at window edge (post %0d cycles after pre)", $time, T_PRE+2);
        do_rst();
        apply_spikes(1'b1, 1'b0);       // pre edge; pre_timer → 0
        idle_cycles(T_PRE + 1);         // pre_timer → 1, 2, 3
        apply_spikes(1'b0, 1'b1);       // post fires; pre_timer = 3 ≥ 0 → LTP
        check("on    | LTP at window edge", elig_on, 9'sd12);
        idle_cycles(2);

        // ==================================================================
        // TEST 7: LTP window miss -- post fires T_PRE+3 cycles after pre
        //
        // After T_PRE+2 idles, pre_timer has cycled through 3 and been set to
        // DISABLED (−1); post edge sees pre_timer < 0 → no LTP.
        // ==================================================================
        $display("\n[%0t] TEST 7: LTP window miss (post %0d cycles after pre)", $time, T_PRE+3);
        do_rst();
        apply_spikes(1'b1, 1'b0);       // pre edge; pre_timer → 0
        idle_cycles(T_PRE + 2);         // pre_timer → 1, 2, 3, DISABLED
        apply_spikes(1'b0, 1'b1);       // post fires; pre_timer = -1 < 0 → no LTP
        check("on    | LTP window miss → no STDP", elig_on, 9'sd0);
        idle_cycles(2);

        // ==================================================================
        // TEST 8: LTD window edge -- pre fires T_POST+2 cycles after post
        //
        // Symmetric to TEST 6 using post_timer.
        //   e_comb = 0 − 64 − (−64 >>> 2) = −64 + 16 = −48
        // ==================================================================
        $display("\n[%0t] TEST 8: LTD at window edge (pre %0d cycles after post)", $time, T_POST+2);
        do_rst();
        apply_spikes(1'b0, 1'b1);       // post edge; post_timer → 0
        idle_cycles(T_POST + 1);        // post_timer → 1, 2, 3
        apply_spikes(1'b1, 1'b0);       // pre fires; post_timer = 3 ≥ 0 → LTD
        check("on    | LTD at window edge", elig_on, -9'sd48);
        idle_cycles(2);

        // ==================================================================
        // TEST 9: LTD window miss -- pre fires T_POST+3 cycles after post
        //
        // Symmetric to TEST 7 using post_timer.
        // ==================================================================
        $display("\n[%0t] TEST 9: LTD window miss (pre %0d cycles after post)", $time, T_POST+3);
        do_rst();
        apply_spikes(1'b0, 1'b1);       // post edge; post_timer → 0
        idle_cycles(T_POST + 2);        // post_timer → 1, 2, 3, DISABLED
        apply_spikes(1'b1, 1'b0);       // pre fires; post_timer = -1 < 0 → no LTD
        check("on    | LTD window miss → no STDP", elig_on, 9'sd0);
        idle_cycles(2);

        // ==================================================================
        // TEST 10: MAX clamp -- single LTP saturates elig_trace at MAX_E_TRACE
        //
        // dut_clamp: DW_POS=500
        //   e_comb = 0 + 500 − (500 >>> 2) = 375 > MAX_E_TRACE(255) → 255
        // ==================================================================
        $display("\n[%0t] TEST 10: MAX clamp -- LTP with DW_POS=500", $time);
        do_rst();
        apply_spikes(1'b1, 1'b0);  // pre fires
        apply_spikes(1'b0, 1'b1);  // post fires → LTP on dut_clamp (375 > 255)
        check("clamp | LTP clamped to MAX_E_TRACE (255)", elig_clamp, 9'sd255);
        idle_cycles(2);

        // ==================================================================
        // TEST 11: MIN clamp -- single LTD saturates elig_trace at MIN_E_TRACE
        //
        // dut_clamp: DW_NEG=500
        //   e_comb = 0 − 500 − (−500 >>> 2) = −375 < MIN_E_TRACE(−256) → −256
        // ==================================================================
        $display("\n[%0t] TEST 11: MIN clamp -- LTD with DW_NEG=500", $time);
        do_rst();
        apply_spikes(1'b0, 1'b1);  // post fires
        apply_spikes(1'b1, 1'b0);  // pre fires → LTD on dut_clamp (−375 < −256)
        check("clamp | LTD clamped to MIN_E_TRACE (-256)", elig_clamp, 9'sh100);
        idle_cycles(2);

        // ==================================================================
        // Summary
        // ==================================================================
        $display("\n[%0t] ===== Testbench complete: %0d passed, %0d failed =====",
                 $time, pass_count, fail_count);

        if (fail_count == 0)
            $display("[%0t] ALL TESTS PASSED", $time);
        else
            $display("[%0t] %0d TEST(S) FAILED -- see FAIL lines above", $time, fail_count);

        $finish;
    end

    // --------------------------------------------------------------------------
    // Waveform dump (uncomment for iVerilog / non-Vivado flows)
    // --------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_eligibility_updater.vcd");
        $dumpvars(0, tb_eligibility_updater);
    end

endmodule
