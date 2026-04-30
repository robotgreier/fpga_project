`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/13/2026
// Design Name:
// Module Name: tb_LIF_core
// Project Name:
// Target Devices:
// Tool Versions:
// Description: Testbench for LIF_core -- covers membrane integration,
//              threshold/spike/reset, decay, and lateral inhibition.
//
// Dependencies: LIF_core.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module tb_LIF_core ();

    // --------------------------------------------------------------------------
    // Parameters
    // --------------------------------------------------------------------------
    localparam int DECAY     = 64;
    localparam int THRESHOLD = 1024;
    localparam int RESET     = 0;

    // --------------------------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------------------------
    logic        clk;
    logic        rst;
    logic        run  = 1'b1;  // always enabled: unit test, not gating
    logic        inhibit;
    logic [15:0] i_syn;
    logic        spk;
    logic [15:0] pre_reset_mem;

    // --------------------------------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------------------------------
    LIF_core #(
        .DECAY    (DECAY),
        .THRESHOLD(THRESHOLD),
        .RESET    (RESET)
    ) dut (
        .clk          (clk),
        .run          (run),
        .rst          (rst),
        .inhibit      (inhibit),
        .i_syn        (i_syn),
        .spk          (spk),
        .pre_reset_mem(pre_reset_mem)
    );

    // --------------------------------------------------------------------------
    // Clock generation -- 10 ns period (100 MHz)
    // --------------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --------------------------------------------------------------------------
    // Helper task: drive one synaptic input + inhibit value for one clock cycle
    // --------------------------------------------------------------------------
    task automatic apply_input(input logic [15:0] syn_val, input logic inh_val);
        @(negedge clk);
        i_syn   = syn_val;
        inhibit = inh_val;
        rst     = 1'b0;
        @(posedge clk);
        #1; // let outputs settle
    endtask

    // --------------------------------------------------------------------------
    // Helper task: idle (zero input, no inhibit) for N cycles
    // --------------------------------------------------------------------------
    task automatic idle_cycles(input int n);
        repeat (n) apply_input(16'd0, 1'b0);
    endtask

    // --------------------------------------------------------------------------
    // Continuous monitor: print membrane and spike on every posedge
    // --------------------------------------------------------------------------
    always @(posedge clk) begin
        #1;
        $display("[%0t ns] i_syn=%0d  pre_reset_mem=%0d  spk=%b",
                 $time, i_syn, pre_reset_mem, spk);
    end

    // --------------------------------------------------------------------------
    // Stimulus
    // --------------------------------------------------------------------------
    initial begin
        // ----- Initialise -----
        rst     = 1'b1;
        inhibit = 1'b0;
        i_syn   = 16'd0;

        // ------------------------------------------------------------------
        // INIT: Hold rst high for 2 cycles to bring mem/spk/pre_reset_mem
        // to RESET (0) before any test begins.
        // ------------------------------------------------------------------
        $display("[%0t] INIT: asserting rst", $time);
        @(negedge clk); @(posedge clk); #1;
        @(negedge clk); @(posedge clk); #1;
        rst = 1'b0;

        // ==================================================================
        // TEST 1: Gradual accumulation to spike
        // Drive i_syn = 150 every cycle.  With DECAY = 64 the net gain is
        // 86 LSB/cycle (once mem > 64), so it takes ~12 cycles to cross
        // THRESHOLD = 1024 and produce a spike.
        //
        // Expected mem trajectory (approximate):
        //   0 -> 150 -> 236 -> 322 -> 408 -> 494 -> 580 -> 666
        //     -> 752 -> 838 -> 924 -> 1010 -> SPIKE (1096 >= 1024)
        // ==================================================================
        $display("[%0t] TEST 1: gradual accumulation -- spike expected ~cycle 12", $time);
        repeat (15) apply_input(16'd150, 1'b0);
        idle_cycles(3);

        // ==================================================================
        // TEST 2: Membrane accumulation -- no spike expected
        // Apply sub-threshold input over several cycles; membrane should
        // accumulate but not cross THRESHOLD.
        // ==================================================================
        $display("[%0t] TEST 2: sub-threshold accumulation", $time);
        repeat (5) apply_input(16'd256, 1'b0);  // net gain 192/cycle
        idle_cycles(3);

        // ==================================================================
        // TEST 3: Single-shot threshold crossing -- spike expected
        // Drive enough current to push membrane >= THRESHOLD in one shot.
        // ==================================================================
        $display("[%0t] TEST 3: single-shot threshold crossing / spike", $time);
        apply_input(16'd1024, 1'b0);
        idle_cycles(3);

        // ==================================================================
        // TEST 4: Decay -- membrane should decay when input is zero
        // ==================================================================
        $display("[%0t] TEST 4: decay", $time);
        apply_input(16'd400, 1'b0);   // charge membrane
        repeat (8) apply_input(16'd0, 1'b0);   // watch it decay by 64/cycle
        idle_cycles(2);

        // ==================================================================
        // TEST 5: Lateral inhibition -- spike suppressed, membrane reset
        // ==================================================================
        $display("[%0t] TEST 5: lateral inhibition", $time);
        apply_input(16'd512,  1'b0);  // build up some membrane potential
        apply_input(16'd1024, 1'b1);  // inhibit active -- spk must stay 0
        idle_cycles(3);

        // ==================================================================
        // TEST 6: Repeated spiking -- membrane resets after each spike
        // ==================================================================
        $display("[%0t] TEST 6: repeated spiking", $time);
        repeat (6) apply_input(16'd1100, 1'b0);
        idle_cycles(3);

        // ==================================================================
        // Add more test cases here as needed
        // ==================================================================

        $display("[%0t] Testbench complete.", $time);
        $finish;
    end

    // --------------------------------------------------------------------------
    // Optional: waveform dump (uncomment for iVerilog / non-Vivado flows)
    // --------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_LIF_core.vcd");
        $dumpvars(0, tb_LIF_core);
    end

endmodule
