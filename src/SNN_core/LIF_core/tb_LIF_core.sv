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
    localparam int DECAY     = 256;
    localparam int THRESHOLD = 1024;
    localparam int RESET     = 0;

    // --------------------------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------------------------
    logic        clk;
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
    // Stimulus
    // --------------------------------------------------------------------------
    initial begin
        // ----- Initialise -----
        inhibit = 1'b0;
        i_syn   = 16'd0;

        // Allow DUT to come out of unknown state
        idle_cycles(2);

        // ==================================================================
        // TEST 1: Membrane accumulation -- no spike expected
        // Apply sub-threshold input over several cycles; membrane should
        // accumulate but not cross THRESHOLD.
        // ==================================================================
        $display("[%0t] TEST 1: sub-threshold accumulation", $time);
        repeat (3) apply_input(16'd300, 1'b0);  // 300 each cycle, well below 1024
        idle_cycles(2);

        // ==================================================================
        // TEST 2: Threshold crossing -- spike expected
        // Drive enough current to push membrane >= THRESHOLD in one shot.
        // ==================================================================
        $display("[%0t] TEST 2: threshold crossing / spike", $time);
        apply_input(16'd1024, 1'b0);  // should trigger spk on next posedge
        idle_cycles(2);

        // ==================================================================
        // TEST 3: Decay -- membrane should decay when input is zero
        // ==================================================================
        $display("[%0t] TEST 3: decay", $time);
        apply_input(16'd512, 1'b0);   // charge membrane to 512
        apply_input(16'd0,   1'b0);   // one decay cycle  (512 - 256 = 256)
        apply_input(16'd0,   1'b0);   // another decay    (256 - 256 = 0)
        idle_cycles(2);

        // ==================================================================
        // TEST 4: Lateral inhibition -- spike suppressed, membrane reset
        // ==================================================================
        $display("[%0t] TEST 4: lateral inhibition", $time);
        apply_input(16'd512,  1'b0);  // build up some membrane potential
        apply_input(16'd1024, 1'b1);  // inhibit active -- spk must stay 0
        idle_cycles(2);

        // ==================================================================
        // TEST 5: Repeated spiking -- membrane resets after each spike
        // ==================================================================
        $display("[%0t] TEST 5: repeated spiking", $time);
        repeat (4) apply_input(16'd1100, 1'b0);
        idle_cycles(2);

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
