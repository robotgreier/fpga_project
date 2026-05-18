`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/13/2026
// Design Name:
// Module Name: tb_apply_reward
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Testbench for apply_reward -- covers all three learning modes
//              (None / R-STDP / STDP), reward_en gating, sign handling, and
//              boundary values.
//
// Dependencies: apply_reward.sv
//
// Revision:
// Revision 0.02 - Updated for combinational apply_reward (removed registered
//                 TEST 0 / TEST 10 hold assumptions)
//
//////////////////////////////////////////////////////////////////////////////////

module tb_apply_reward ();

    // --------------------------------------------------------------------------
    // Parameters
    // --------------------------------------------------------------------------
    localparam int LR_SHIFT = 2;  // Must match DUT default

    // --------------------------------------------------------------------------
    // Shared DUT signals
    // --------------------------------------------------------------------------
    logic              clk;
    logic signed [3:0] dopamine;
    logic signed [8:0] elig_trace;
    logic              reward_en;
    logic              rst;

    // Output per learning-mode instance
    logic signed [8:0] delta_w_none;   // LEARNING_MODE = 0
    logic signed [8:0] delta_w_rstdp;  // LEARNING_MODE = 1
    logic signed [8:0] delta_w_stdp;   // LEARNING_MODE = 2

    // --------------------------------------------------------------------------
    // DUT instantiation -- one per learning mode
    // --------------------------------------------------------------------------
    apply_reward #(.LR_SHIFT(LR_SHIFT), .LEARNING_MODE(0)) dut_none (
        .dopamine   (dopamine),
        .elig_trace (elig_trace),
        .reward_en  (reward_en),
        .delta_w    (delta_w_none)
    );

    apply_reward #(.LR_SHIFT(LR_SHIFT), .LEARNING_MODE(1)) dut_rstdp (
        .dopamine   (dopamine),
        .elig_trace (elig_trace),
        .reward_en  (reward_en),
        .delta_w    (delta_w_rstdp)
    );

    apply_reward #(.LR_SHIFT(LR_SHIFT), .LEARNING_MODE(2)) dut_stdp (
        .dopamine   (dopamine),
        .elig_trace (elig_trace),
        .reward_en  (reward_en),
        .delta_w    (delta_w_stdp)
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
    // Helper task: drive inputs for one clock cycle
    // --------------------------------------------------------------------------
    task automatic apply_inputs(
        input logic signed [3:0] dop_val,
        input logic signed [8:0] elig_val,
        input logic              en_val
    );
        @(negedge clk);
        dopamine   = dop_val;
        elig_trace = elig_val;
        reward_en  = en_val;
        @(posedge clk);
        #1;  // let outputs settle
    endtask

    // --------------------------------------------------------------------------
    // Helper task: idle (zero input, reward disabled) for N cycles
    // --------------------------------------------------------------------------
    task automatic idle_cycles(input int n);
        repeat (n) apply_inputs(4'sd0, 9'sd0, 1'b0);
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
            $display("  PASS  %s : delta_w = %0d", label, got);
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
        $display("[%0t ns]  dop=%0d  elig=%0d  en=%b | none=%0d  rstdp=%0d  stdp=%0d",
                 $time, dopamine, elig_trace, reward_en,
                 delta_w_none, delta_w_rstdp, delta_w_stdp);
    end

    // --------------------------------------------------------------------------
    // Stimulus
    // --------------------------------------------------------------------------
    initial begin
        // ----- Initialise -----
        dopamine   = 4'sd0;
        elig_trace = 9'sd0;
        reward_en  = 1'b0;
        rst        = 1'b1;

        idle_cycles(2);
        @(negedge clk);
        rst = 1'b0;

        // ==================================================================
        // TEST 0: reward_en=0 -- delta_w must be zero regardless of inputs
        //
        // apply_reward is combinational: rst has no effect on delta_w.
        // Gating is purely through reward_en.
        // ==================================================================
        $display("\n[%0t] TEST 0: reward_en disabled -- output must be zero", $time);
        apply_inputs(4'sd5, 9'sd200, 1'b0);
        check("none  | en=0, elig=200, dop=5", delta_w_none,  8'sd0);
        check("rstdp | en=0, elig=200, dop=5", delta_w_rstdp, 8'sd0);
        check("stdp  | en=0, elig=200, dop=5", delta_w_stdp,  8'sd0);
        idle_cycles(1);

        // ==================================================================
        // TEST 1: reward_en=1 then reward_en=0 -- output returns to zero
        //
        // Combinational: delta_w tracks reward_en with no memory.
        // en=0 always produces 0, regardless of prior state.
        // ==================================================================
        $display("\n[%0t] TEST 1: reward_en gating -- en=0 gives zero, not hold", $time);
        apply_inputs(4'sd0, 9'sd100, 1'b1);   // en=1 → stdp delta_w=25
        check("stdp  | en=1, elig=100 : delta_w=25", delta_w_stdp, 8'sd25);
        apply_inputs(4'sd0, 9'sd200, 1'b0);   // en=0 → delta_w returns to 0
        check("stdp  | en=0, elig=200 : delta_w=0 (no hold)", delta_w_stdp, 8'sd0);
        idle_cycles(1);

        // ==================================================================
        // TEST 2: STDP mode -- positive eligibility trace
        //
        // delta_w = elig_trace >>> LR_SHIFT
        //   elig=100 -> 100 >>> 2 = 25
        //   elig=200 -> 200 >>> 2 = 50
        // ==================================================================
        $display("\n[%0t] TEST 2: STDP -- positive eligibility trace", $time);
        apply_inputs(4'sd0, 9'sd100, 1'b1);
        check("stdp  | elig=100, dop=0, en=1", delta_w_stdp,  8'sd25);

        apply_inputs(4'sd0, 9'sd200, 1'b1);
        check("stdp  | elig=200, dop=0, en=1", delta_w_stdp,  8'sd50);
        idle_cycles(1);

        // ==================================================================
        // TEST 3: STDP mode -- negative eligibility trace
        //
        // Arithmetic right shift must sign-extend:
        //   elig=-100 -> -100 >>> 2 = -25
        //   elig=-200 -> -200 >>> 2 = -50
        // ==================================================================
        $display("\n[%0t] TEST 3: STDP -- negative eligibility trace", $time);
        apply_inputs(4'sd0, -9'sd100, 1'b1);
        check("stdp  | elig=-100, dop=0, en=1", delta_w_stdp,  -8'sd25);

        apply_inputs(4'sd0, -9'sd200, 1'b1);
        check("stdp  | elig=-200, dop=0, en=1", delta_w_stdp,  -8'sd50);
        idle_cycles(1);

        // ==================================================================
        // TEST 4: STDP mode -- zero eligibility trace
        //
        // delta_w = 0 regardless of dopamine.
        // ==================================================================
        $display("\n[%0t] TEST 4: STDP -- zero eligibility trace", $time);
        apply_inputs(4'sd7, 9'sd0, 1'b1);
        check("stdp  | elig=0, dop=7, en=1", delta_w_stdp, 8'sd0);
        idle_cycles(1);

        // ==================================================================
        // TEST 5: R-STDP -- positive dopamine, positive trace
        //
        // delta_w = (elig_trace * dopamine) >>> LR_SHIFT
        //   elig=100, dop=3  -> 300  >>> 2 = 75
        //   elig=50,  dop=7  -> 350  >>> 2 = 87
        // ==================================================================
        $display("\n[%0t] TEST 5: R-STDP -- positive dopamine, positive trace", $time);
        apply_inputs(4'sd3, 9'sd100, 1'b1);
        check("rstdp | elig=100, dop=3,  en=1", delta_w_rstdp,  8'sd75);

        apply_inputs(4'sd7, 9'sd50, 1'b1);
        check("rstdp | elig=50,  dop=7,  en=1", delta_w_rstdp,  8'sd87);
        idle_cycles(1);

        // ==================================================================
        // TEST 6: R-STDP -- negative dopamine, positive trace
        //
        //   elig=100, dop=-3 -> -300 >>> 2 = -75
        //   elig=50,  dop=-7 -> -350 >>> 2 = -88  (floor of -87.5)
        // ==================================================================
        $display("\n[%0t] TEST 6: R-STDP -- negative dopamine, positive trace", $time);
        apply_inputs(-4'sd3, 9'sd100, 1'b1);
        check("rstdp | elig=100, dop=-3, en=1", delta_w_rstdp,  -8'sd75);

        apply_inputs(-4'sd7, 9'sd50, 1'b1);
        check("rstdp | elig=50,  dop=-7, en=1", delta_w_rstdp,  -8'sd88);
        idle_cycles(1);

        // ==================================================================
        // TEST 7: R-STDP -- positive dopamine, negative trace
        //
        //   elig=-100, dop=3 -> -300 >>> 2 = -75
        //   elig=-50,  dop=7 -> -350 >>> 2 = -88
        // ==================================================================
        $display("\n[%0t] TEST 7: R-STDP -- positive dopamine, negative trace", $time);
        apply_inputs(4'sd3, -9'sd100, 1'b1);
        check("rstdp | elig=-100, dop=3,  en=1", delta_w_rstdp, -8'sd75);

        apply_inputs(4'sd7, -9'sd50, 1'b1);
        check("rstdp | elig=-50,  dop=7,  en=1", delta_w_rstdp, -8'sd88);
        idle_cycles(1);

        // ==================================================================
        // TEST 8: R-STDP -- zero dopamine
        //
        // Product is zero regardless of elig_trace.
        // ==================================================================
        $display("\n[%0t] TEST 8: R-STDP -- zero dopamine", $time);
        apply_inputs(4'sd0, 9'sd255, 1'b1);
        check("rstdp | elig=255, dop=0, en=1", delta_w_rstdp, 8'sd0);
        idle_cycles(1);

        // ==================================================================
        // TEST 9: No-learning mode -- delta_w always zero
        //
        // Regardless of inputs the no-learning DUT must output zero.
        // ==================================================================
        $display("\n[%0t] TEST 9: No-learning mode -- delta_w must always be zero", $time);
        apply_inputs(4'sd7, 9'sd200, 1'b1);
        check("none  | elig=200, dop=7,  en=1", delta_w_none, 8'sd0);

        apply_inputs(-4'sd8, -9'sd255, 1'b1);
        check("none  | elig=-255, dop=-8, en=1", delta_w_none, 8'sd0);
        idle_cycles(1);

        // ==================================================================
        // TEST 10: Boundary -- maximum positive eligibility trace (STDP)
        //
        // elig=255 -> 255 >>> 2 = 63 (no overflow within 8-bit signed range)
        // ==================================================================
        $display("\n[%0t] TEST 10: STDP -- maximum positive elig_trace (255)", $time);
        apply_inputs(4'sd0, 9'sd255, 1'b1);
        check("stdp  | elig=255, dop=0, en=1", delta_w_stdp, 8'sd63);
        idle_cycles(1);

        // ==================================================================
        // TEST 11: Boundary -- maximum negative eligibility trace (STDP)
        //
        // elig=-256 -> -256 >>> 2 = -64
        // ==================================================================
        $display("\n[%0t] TEST 11: STDP -- maximum negative elig_trace (-256)", $time);
        apply_inputs(4'sd0, -9'sd256, 1'b1);
        check("stdp  | elig=-256, dop=0, en=1", delta_w_stdp, -8'sd64);
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
    // Waveform dump
    // --------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_apply_reward.vcd");
        $dumpvars(0, tb_apply_reward);
    end

endmodule
