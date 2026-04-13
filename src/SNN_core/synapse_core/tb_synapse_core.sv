`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/13/2026
// Design Name:
// Module Name: tb_synapse_core
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Testbench for synapse_core -- covers reset, no-learning mode,
//              I_syn forwarding, reward_en gating, LTP/LTD weight updates via
//              R-STDP and STDP, weight clamping, and boundary values.
//
// Dependencies: synapse_core.sv, eligibility_updater.sv, apply_reward.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module tb_synapse_core ();

    // --------------------------------------------------------------------------
    // Parameters matching DUT defaults
    // --------------------------------------------------------------------------
    localparam int LR_SHIFT    = 2;
    localparam int T_PRE       = 2;
    localparam int T_POST      = 2;
    localparam int TAU_E_SHIFT = 2;
    localparam int DW_POS      = 16;
    localparam int DW_NEG      = 64;
    localparam int W_MIN       = 8;
    localparam int W_MAX       = 255;

    // --------------------------------------------------------------------------
    // Shared DUT input signals
    // --------------------------------------------------------------------------
    logic              clk;
    logic              rst;
    logic              pre_spk;
    logic              post_spk;
    logic signed [3:0] dopamine;
    logic              reward_en;
    logic        [7:0] w_syn;

    // Outputs per learning-mode instance
    logic [7:0] w_next_none;   // LEARNING_MODE = 0  (no learning)
    logic [7:0] I_syn_none;
    logic [7:0] w_next_rstdp;  // LEARNING_MODE = 1  (R-STDP)
    logic [7:0] I_syn_rstdp;
    logic [7:0] w_next_stdp;   // LEARNING_MODE = 2  (STDP)
    logic [7:0] I_syn_stdp;

    // --------------------------------------------------------------------------
    // DUT instantiation -- one per learning mode
    // --------------------------------------------------------------------------
    synapse_core #(
        .LR_SHIFT    (LR_SHIFT),
        .T_PRE       (T_PRE),
        .T_POST      (T_POST),
        .TAU_E_SHIFT (TAU_E_SHIFT),
        .DW_POS      (DW_POS),
        .DW_NEG      (DW_NEG),
        .W_MIN       (W_MIN),
        .W_MAX       (W_MAX),
        .LEARNING_MODE(0)
    ) dut_none (
        .clk       (clk),
        .rst       (rst),
        .pre_spk   (pre_spk),
        .post_spk  (post_spk),
        .dopamine  (dopamine),
        .reward_en (reward_en),
        .w_syn     (w_syn),
        .w_next    (w_next_none),
        .I_syn     (I_syn_none)
    );

    synapse_core #(
        .LR_SHIFT    (LR_SHIFT),
        .T_PRE       (T_PRE),
        .T_POST      (T_POST),
        .TAU_E_SHIFT (TAU_E_SHIFT),
        .DW_POS      (DW_POS),
        .DW_NEG      (DW_NEG),
        .W_MIN       (W_MIN),
        .W_MAX       (W_MAX),
        .LEARNING_MODE(1)
    ) dut_rstdp (
        .clk       (clk),
        .rst       (rst),
        .pre_spk   (pre_spk),
        .post_spk  (post_spk),
        .dopamine  (dopamine),
        .reward_en (reward_en),
        .w_syn     (w_syn),
        .w_next    (w_next_rstdp),
        .I_syn     (I_syn_rstdp)
    );

    synapse_core #(
        .LR_SHIFT    (LR_SHIFT),
        .T_PRE       (T_PRE),
        .T_POST      (T_POST),
        .TAU_E_SHIFT (TAU_E_SHIFT),
        .DW_POS      (DW_POS),
        .DW_NEG      (DW_NEG),
        .W_MIN       (W_MIN),
        .W_MAX       (W_MAX),
        .LEARNING_MODE(2)
    ) dut_stdp (
        .clk       (clk),
        .rst       (rst),
        .pre_spk   (pre_spk),
        .post_spk  (post_spk),
        .dopamine  (dopamine),
        .reward_en (reward_en),
        .w_syn     (w_syn),
        .w_next    (w_next_stdp),
        .I_syn     (I_syn_stdp)
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
    // Helper task: drive all inputs for one clock cycle
    // --------------------------------------------------------------------------
    task automatic apply_inputs(
        input logic              pre_val,
        input logic              post_val,
        input logic signed [3:0] dop_val,
        input logic              en_val,
        input logic        [7:0] w_val
    );
        @(negedge clk);
        pre_spk   = pre_val;
        post_spk  = post_val;
        dopamine  = dop_val;
        reward_en = en_val;
        w_syn     = w_val;
        @(posedge clk);
        #1;  // let outputs settle
    endtask

    // --------------------------------------------------------------------------
    // Helper task: idle (no spikes, reward disabled) for N cycles
    // --------------------------------------------------------------------------
    task automatic idle_cycles(input int n);
        repeat (n) apply_inputs(1'b0, 1'b0, 4'sd0, 1'b0, w_syn);
    endtask

    // --------------------------------------------------------------------------
    // Helper task: assert reset for two cycles then release
    // --------------------------------------------------------------------------
    task automatic do_rst();
        @(negedge clk);
        rst       = 1'b1;
        pre_spk   = 1'b0;
        post_spk  = 1'b0;
        dopamine  = 4'sd0;
        reward_en = 1'b0;
        @(posedge clk); #1;
        @(negedge clk); @(posedge clk); #1;
        rst = 1'b0;
    endtask

    // --------------------------------------------------------------------------
    // Assertion helpers: check w_next and I_syn, print PASS / FAIL
    // --------------------------------------------------------------------------
    task automatic check_w(
        input string      label,
        input logic [7:0] got,
        input logic [7:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %s : w_next = %0d", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s : got %0d, expected %0d", label, got, expected);
            fail_count++;
        end
    endtask

    task automatic check_i(
        input string      label,
        input logic [7:0] got,
        input logic [7:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %s : I_syn = %0d", label, got);
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
        $display("[%0t ns]  pre=%b post=%b dop=%0d en=%b w_syn=%0d | none(w=%0d I=%0d)  rstdp(w=%0d I=%0d)  stdp(w=%0d I=%0d)",
                 $time, pre_spk, post_spk, dopamine, reward_en, w_syn,
                 w_next_none, I_syn_none,
                 w_next_rstdp, I_syn_rstdp,
                 w_next_stdp,  I_syn_stdp);
    end

    // --------------------------------------------------------------------------
    // Stimulus
    // --------------------------------------------------------------------------
    initial begin
        // ----- Initialise -----
        rst       = 1'b1;
        pre_spk   = 1'b0;
        post_spk  = 1'b0;
        dopamine  = 4'sd0;
        reward_en = 1'b0;
        w_syn     = 8'd100;

        // ==================================================================
        // TEST 0: Reset -- w_next must equal W_MIN while rst is asserted
        //
        // synapse_core resets w_next to W_MIN (8). Sub-modules reset their
        // own state (elig_trace → 0, delta_w → 0) via the propagated rst.
        // ==================================================================
        $display("\n[%0t] TEST 0: Reset -- w_next must be W_MIN during rst", $time);
        @(negedge clk); @(posedge clk); #1;
        @(negedge clk); @(posedge clk); #1;
        check_w("none  | rst=1", w_next_none,  8'(W_MIN));
        check_w("rstdp | rst=1", w_next_rstdp, 8'(W_MIN));
        check_w("stdp  | rst=1", w_next_stdp,  8'(W_MIN));
        @(negedge clk);
        rst = 1'b0;
        idle_cycles(1);

        // ==================================================================
        // TEST 1: I_syn -- combinational forwarding of w_syn on pre_spk
        //
        // I_syn = pre_spk ? w_syn : 0  (purely combinational).
        // ==================================================================
        $display("\n[%0t] TEST 1: I_syn -- combinational forwarding on pre_spk", $time);
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b0, 8'd100);
        check_i("rstdp | pre=1, w_syn=100 → I_syn=100", I_syn_rstdp, 8'd100);
        apply_inputs(1'b0, 1'b0, 4'sd0, 1'b0, 8'd100);
        check_i("rstdp | pre=0, w_syn=100 → I_syn=0",   I_syn_rstdp, 8'd0);
        idle_cycles(1);

        // ==================================================================
        // TEST 2: No-learning mode -- w_next tracks w_syn with delta_w=0
        //
        // LEARNING_MODE=0: delta_w is always 0 regardless of inputs.
        // w_next = clamp(w_syn + 0) = w_syn each cycle.
        // ==================================================================
        $display("\n[%0t] TEST 2: No-learning mode -- w_next tracks w_syn, delta_w=0", $time);
        do_rst();
        apply_inputs(1'b1, 1'b0, 4'sd7, 1'b1, 8'd100);  // spike + reward ignored
        apply_inputs(1'b0, 1'b1, 4'sd7, 1'b1, 8'd100);
        check_w("none  | mode=0, w_syn=100, reward active → w_next=100", w_next_none, 8'd100);
        idle_cycles(1);

        // ==================================================================
        // TEST 3: STDP LTP -- post fires 1 cycle after pre
        //
        // elig: e = 0 + DW_POS(16) − (16 >>> TAU_E_SHIFT(2)) = 12
        // reward (STDP): delta_w = 12 >>> LR_SHIFT(2) = 3
        // w_next = clamp(100 + 3) = 103
        //
        // Pipeline: elig registered at T1 posedge, delta_w registered at T2
        // posedge, w_next registered at T3 posedge → need 1 idle after pair.
        // ==================================================================
        $display("\n[%0t] TEST 3: STDP LTP -- post 1 cycle after pre", $time);
        do_rst();
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b1, 8'd100);  // pre edge
        apply_inputs(1'b0, 1'b1, 4'sd0, 1'b1, 8'd100);  // post edge (LTP)
        idle_cycles(1);  // allow two-stage pipeline to propagate
        check_w("stdp  | LTP: w_syn=100, delta_w=3 → w_next=103", w_next_stdp, 8'd103);
        idle_cycles(1);

        // ==================================================================
        // TEST 4: STDP LTD -- pre fires 1 cycle after post
        //
        // elig: e = 0 − DW_NEG(64) − (−64 >>> 2) = −48
        // delta_w = −48 >>> 2 = −12
        // w_next = clamp(100 − 12) = 88
        // ==================================================================
        $display("\n[%0t] TEST 4: STDP LTD -- pre 1 cycle after post", $time);
        do_rst();
        apply_inputs(1'b0, 1'b1, 4'sd0, 1'b1, 8'd100);  // post edge
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b1, 8'd100);  // pre edge (LTD)
        idle_cycles(1);
        check_w("stdp  | LTD: w_syn=100, delta_w=-12 → w_next=88", w_next_stdp, 8'd88);
        idle_cycles(1);

        // ==================================================================
        // TEST 5: R-STDP LTP -- positive dopamine scales delta_w
        //
        // e_trace = 12 (same as TEST 3)
        // delta_w = (12 * dop(3)) >>> 2 = 36 >>> 2 = 9
        // w_next = clamp(100 + 9) = 109
        // ==================================================================
        $display("\n[%0t] TEST 5: R-STDP LTP -- positive dopamine", $time);
        do_rst();
        apply_inputs(1'b1, 1'b0, 4'sd3, 1'b1, 8'd100);  // pre edge
        apply_inputs(1'b0, 1'b1, 4'sd3, 1'b1, 8'd100);  // post edge (LTP)
        idle_cycles(1);
        check_w("rstdp | LTP dop=3: w_syn=100, delta_w=9 → w_next=109", w_next_rstdp, 8'd109);
        idle_cycles(1);

        // ==================================================================
        // TEST 6: R-STDP LTP -- negative dopamine reverses delta_w
        //
        // e_trace = 12 (LTP direction, acausal pairing under punishment)
        // delta_w = (12 * dop(-3)) >>> 2 = -36 >>> 2 = -9
        // w_next = clamp(100 − 9) = 91
        // ==================================================================
        $display("\n[%0t] TEST 6: R-STDP LTP -- negative dopamine (punishment reversal)", $time);
        do_rst();
        apply_inputs(1'b1, 1'b0, -4'sd3, 1'b1, 8'd100);  // pre edge
        apply_inputs(1'b0, 1'b1, -4'sd3, 1'b1, 8'd100);  // post edge
        idle_cycles(1);
        check_w("rstdp | LTP dop=-3: w_syn=100, delta_w=-9 → w_next=91", w_next_rstdp, 8'd91);
        idle_cycles(1);

        // ==================================================================
        // TEST 7: reward_en gating -- w_next holds when reward_en=0
        //
        // After a rewarded LTP (delta_w=3, w_next=103), disabling reward_en
        // holds delta_w at its last registered value. A new spike pair with
        // en=0 must not update w_next further.
        // ==================================================================
        $display("\n[%0t] TEST 7: reward_en gating -- w_next holds last value", $time);
        do_rst();
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b1, 8'd100);  // pre edge, en=1
        apply_inputs(1'b0, 1'b1, 4'sd0, 1'b1, 8'd100);  // post edge, en=1
        idle_cycles(1);
        check_w("stdp  | baseline LTP: w_next=103", w_next_stdp, 8'd103);
        // Disable reward -- delta_w register holds; w_next = clamp(100 + 3) still
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b0, 8'd100);  // pre edge, en=0
        apply_inputs(1'b0, 1'b1, 4'sd0, 1'b0, 8'd100);  // post edge, en=0
        idle_cycles(1);
        check_w("stdp  | en=0 hold: w_next still 103", w_next_stdp, 8'd103);
        idle_cycles(1);

        // ==================================================================
        // TEST 8: W_MAX clamp -- LTP from high w_syn saturates at W_MAX
        //
        // w_syn=253, delta_w=3 (STDP LTP) → w_sum=256 > W_MAX(255) → 255
        // ==================================================================
        $display("\n[%0t] TEST 8: W_MAX clamp -- LTP saturates at W_MAX (255)", $time);
        do_rst();
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b1, 8'd253);  // pre edge
        apply_inputs(1'b0, 1'b1, 4'sd0, 1'b1, 8'd253);  // post edge (LTP, delta_w=3)
        idle_cycles(1);
        check_w("stdp  | W_MAX clamp: w_syn=253 + 3 → 255", w_next_stdp, 8'(W_MAX));
        idle_cycles(1);

        // ==================================================================
        // TEST 9: W_MIN clamp -- LTD from low w_syn saturates at W_MIN
        //
        // w_syn=15, delta_w=-12 (STDP LTD) → w_sum=3 < W_MIN(8) → 8
        // ==================================================================
        $display("\n[%0t] TEST 9: W_MIN clamp -- LTD saturates at W_MIN (8)", $time);
        do_rst();
        apply_inputs(1'b0, 1'b1, 4'sd0, 1'b1, 8'd15);  // post edge
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b1, 8'd15);  // pre edge (LTD, delta_w=-12)
        idle_cycles(1);
        check_w("stdp  | W_MIN clamp: w_syn=15 - 12 → 8", w_next_stdp, 8'(W_MIN));
        idle_cycles(1);

        // ==================================================================
        // TEST 10: No STDP without spike history (no causal pairing)
        //
        // post alone (no prior pre in window) → no LTP → delta_w stays 0
        // w_next = clamp(w_syn + 0) = w_syn
        // ==================================================================
        $display("\n[%0t] TEST 10: No STDP without spike history", $time);
        do_rst();
        apply_inputs(1'b0, 1'b1, 4'sd0, 1'b1, 8'd100);  // post only
        idle_cycles(1);
        check_w("stdp  | post alone → no LTP → w_next=100", w_next_stdp, 8'd100);
        idle_cycles(T_PRE + 3);                           // let timers expire
        apply_inputs(1'b1, 1'b0, 4'sd0, 1'b1, 8'd100);  // pre only
        idle_cycles(1);
        check_w("stdp  | pre alone  → no LTD → w_next=100", w_next_stdp, 8'd100);
        idle_cycles(1);

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
        $dumpfile("tb_synapse_core.vcd");
        $dumpvars(0, tb_synapse_core);
    end

endmodule
