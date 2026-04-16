`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_WTA
// Description: Testbench for WTA (Winner-Take-All) -- covers spiking-pool
//              competition, no-winner case (no spikes → winner_valid=0),
//              argmax selection, tie-breaking, and boundary values.
//
//              WTA is purely combinational. Clock removed entirely.
//              All inputs are driven simultaneously in a single procedural
//              block; a #10 hold lets outputs settle before assertions fire.
//
// Dependencies: WTA.sv
//
// Revision:
// Revision 0.03 - Removed clock-based stimulus to eliminate delta-cycle skew
//                 between spk and pre_reset_mem assignments.
//////////////////////////////////////////////////////////////////////////////////

module tb_WTA ();

    // --------------------------------------------------------------------------
    // Parameters
    // --------------------------------------------------------------------------
    localparam int N_OUTPUTS = 3;
    localparam int IDX_W     = $clog2(N_OUTPUTS);  // 2

    // --------------------------------------------------------------------------
    // DUT signals
    // --------------------------------------------------------------------------
    logic [N_OUTPUTS-1:0]         spk;
    logic [N_OUTPUTS-1:0][15:0]   pre_reset_mem;
    logic [IDX_W-1:0]             winner_idx;
    logic                         winner_valid;

    // --------------------------------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------------------------------
    WTA #(
        .N_OUTPUTS(N_OUTPUTS)
    ) dut (
        .spk          (spk),
        .pre_reset_mem(pre_reset_mem),
        .winner_idx   (winner_idx),
        .winner_valid (winner_valid)
    );

    // --------------------------------------------------------------------------
    // Pass / fail counters
    // --------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    // --------------------------------------------------------------------------
    // Helper task: drive ALL inputs simultaneously, then hold 10 ns.
    //
    // All four assignments are in the same procedural time step -- no
    // delta-cycle skew between spk and pre_reset_mem.  The #10 hold gives
    // the combinational cone time to settle before assertions read outputs.
    // --------------------------------------------------------------------------
    task automatic apply_inputs(
        input logic [N_OUTPUTS-1:0] spk_val,
        input logic [15:0]          mem0,
        input logic [15:0]          mem1,
        input logic [15:0]          mem2
    );
        spk              = spk_val;
        pre_reset_mem[0] = mem0;
        pre_reset_mem[1] = mem1;
        pre_reset_mem[2] = mem2;
        #10;  // hold: all outputs fully settled before assertions
        $display("[%0t ns]  spk=%03b  mem=[%0d,%0d,%0d]  winner_valid=%0b  winner_idx=%0d",
                 $time, spk,
                 pre_reset_mem[0], pre_reset_mem[1], pre_reset_mem[2],
                 winner_valid, winner_idx);
    endtask

    // --------------------------------------------------------------------------
    // Helper task: idle (no spikes, zero membranes) for N notional cycles
    // --------------------------------------------------------------------------
    task automatic idle_cycles(input int n);
        repeat (n) apply_inputs(3'b000, 16'd0, 16'd0, 16'd0);
    endtask

    // --------------------------------------------------------------------------
    // Assertion helpers
    // --------------------------------------------------------------------------
    task automatic check_idx(
        input string            label,
        input logic [IDX_W-1:0] got,
        input logic [IDX_W-1:0] expected
    );
        if (got === expected) begin
            $display("  PASS  %s : winner_idx = %0d", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s : got %0d, expected %0d", label, got, expected);
            fail_count++;
        end
    endtask

    task automatic check_valid(
        input string label,
        input logic  got,
        input logic  expected
    );
        if (got === expected) begin
            $display("  PASS  %s : winner_valid = %0b", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s : got %0b, expected %0b", label, got, expected);
            fail_count++;
        end
    endtask

    // --------------------------------------------------------------------------
    // Stimulus
    // --------------------------------------------------------------------------
    initial begin
        // ----- Initialise -----
        spk              = 3'b000;
        pre_reset_mem[0] = 16'd0;
        pre_reset_mem[1] = 16'd0;
        pre_reset_mem[2] = 16'd0;

        idle_cycles(2);

        // ==================================================================
        // TEST 1: No spikes -- winner_valid must be 0, winner_idx don't-care
        //
        // With no spiking neurons there is no winner regardless of membrane
        // values.
        // ==================================================================
        $display("\n[%0t] TEST 1: No spikes -- winner_valid must be 0", $time);
        apply_inputs(3'b000, 16'd50,   16'd200,  16'd100);
        check_valid("spk=000, mem=[50,200,100]  -> valid=0", winner_valid, 1'b0);

        apply_inputs(3'b000, 16'd0,    16'd0,    16'd0);
        check_valid("spk=000, mem=[0,0,0]       -> valid=0", winner_valid, 1'b0);

        apply_inputs(3'b000, 16'hFFFF, 16'hFFFF, 16'hFFFF);
        check_valid("spk=000, mem=[max,max,max] -> valid=0", winner_valid, 1'b0);
        idle_cycles(1);

        // ==================================================================
        // TEST 2: Single spike -- forced winner, winner_valid=1
        //
        // Only the spiking neuron is in the pool, so it wins even when its
        // membrane is the lowest of the three.
        //   spk=001 (neuron 0 spikes, lowest mem) -> winner=0
        //   spk=010 (neuron 1 spikes, lowest mem) -> winner=1
        //   spk=100 (neuron 2 spikes, lowest mem) -> winner=2
        // ==================================================================
        $display("\n[%0t] TEST 2: Single spike -- forced winner", $time);
        apply_inputs(3'b001, 16'd10,  16'd500, 16'd900);
        check_valid("spk=001                    -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=001, mem=[10,500,900]  -> idx=0",  winner_idx,   IDX_W'(0));

        apply_inputs(3'b010, 16'd900, 16'd10,  16'd500);
        check_valid("spk=010                    -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=010, mem=[900,10,500]  -> idx=1",  winner_idx,   IDX_W'(1));

        apply_inputs(3'b100, 16'd900, 16'd500, 16'd10);
        check_valid("spk=100                    -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=100, mem=[900,500,10]  -> idx=2",  winner_idx,   IDX_W'(2));
        idle_cycles(1);

        // ==================================================================
        // TEST 3: Multiple spikes -- winner is spiking neuron with highest mem
        //
        // Non-spiking neurons are excluded even if they have higher membrane.
        //   spk=011, mem=[300,200,900] -> pool={0,1} (neuron 2 excluded),
        //     competing: mem[0]=300 vs mem[1]=200 -> winner=0
        //   spk=101, mem=[200,900,300] -> pool={0,2} (neuron 1 excluded),
        //     competing: mem[0]=200 vs mem[2]=300 -> winner=2
        //   spk=110, mem=[900,200,300] -> pool={1,2} (neuron 0 excluded),
        //     competing: mem[1]=200 vs mem[2]=300 -> winner=2
        // ==================================================================
        $display("\n[%0t] TEST 3: Multiple spikes -- highest spiking membrane wins", $time);
        apply_inputs(3'b011, 16'd300, 16'd200, 16'd900);
        check_valid("spk=011                        -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=011, mem=[300,200,900]     -> idx=0",  winner_idx,   IDX_W'(0));

        apply_inputs(3'b101, 16'd200, 16'd900, 16'd300);
        check_valid("spk=101                        -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=101, mem=[200,900,300]     -> idx=2",  winner_idx,   IDX_W'(2));

        apply_inputs(3'b110, 16'd900, 16'd200, 16'd300);
        check_valid("spk=110                        -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=110, mem=[900,200,300]     -> idx=2",  winner_idx,   IDX_W'(2));
        idle_cycles(1);

        // ==================================================================
        // TEST 4: All neurons spike -- argmax over all membranes
        //
        //   spk=111, mem=[100,300,200] -> winner=1
        //   spk=111, mem=[100,200,300] -> winner=2
        //   spk=111, mem=[300,200,100] -> winner=0
        // ==================================================================
        $display("\n[%0t] TEST 4: All neurons spike -- argmax over all", $time);
        apply_inputs(3'b111, 16'd100, 16'd300, 16'd200);
        check_valid("spk=111                        -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=111, mem=[100,300,200]     -> idx=1",  winner_idx,   IDX_W'(1));

        apply_inputs(3'b111, 16'd100, 16'd200, 16'd300);
        check_valid("spk=111                        -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=111, mem=[100,200,300]     -> idx=2",  winner_idx,   IDX_W'(2));

        apply_inputs(3'b111, 16'd300, 16'd200, 16'd100);
        check_valid("spk=111                        -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=111, mem=[300,200,100]     -> idx=0",  winner_idx,   IDX_W'(0));
        idle_cycles(1);

        // ==================================================================
        // TEST 5: Tie-breaking -- equal membrane values
        //
        // The loop uses >=, so later indices overwrite on ties.
        // The last (highest-index) spiking neuron with max membrane wins.
        //
        //   spk=111, mem=[100,100,100] -> winner=2 (last equal)
        //   spk=111, mem=[100,100,50]  -> winner=1
        //   spk=111, mem=[100,50,100]  -> winner=2
        //   spk=011, mem=[100,100,0]   -> pool={0,1}, winner=1
        // ==================================================================
        $display("\n[%0t] TEST 5: Tie-breaking -- equal membranes (highest index wins)", $time);
        apply_inputs(3'b111, 16'd100, 16'd100, 16'd100);
        check_idx("spk=111, mem=[100,100,100]     -> idx=2", winner_idx, IDX_W'(2));

        apply_inputs(3'b111, 16'd100, 16'd100, 16'd50);
        check_idx("spk=111, mem=[100,100,50]      -> idx=1", winner_idx, IDX_W'(1));

        apply_inputs(3'b111, 16'd100, 16'd50,  16'd100);
        check_idx("spk=111, mem=[100,50,100]      -> idx=2", winner_idx, IDX_W'(2));

        apply_inputs(3'b011, 16'd100, 16'd100, 16'd0);
        check_idx("spk=011, mem=[100,100,0]       -> idx=1", winner_idx, IDX_W'(1));
        idle_cycles(1);

        // ==================================================================
        // TEST 6: Boundary -- maximum membrane value (16'hFFFF)
        //
        // Ensure no overflow / sign issues in the 16-bit unsigned comparison.
        //   spk=001, mem=[0xFFFF,0,0]       -> winner=0
        //   spk=110, mem=[0,0xFFFF,0xFFFF]  -> winner=2 (tie, highest index)
        //   spk=010, mem=[0xFFFF,0,0xFFFF]  -> winner=1 (only spiker)
        // ==================================================================
        $display("\n[%0t] TEST 6: Boundary -- maximum membrane (0xFFFF)", $time);
        apply_inputs(3'b001, 16'hFFFF, 16'd0,    16'd0);
        check_valid("spk=001                         -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=001, mem=[0xFFFF,0,0]      -> idx=0",  winner_idx,   IDX_W'(0));

        apply_inputs(3'b110, 16'd0,    16'hFFFF, 16'hFFFF);
        check_valid("spk=110                         -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=110, mem=[0,0xFFFF,0xFFFF] -> idx=2",  winner_idx,   IDX_W'(2));

        apply_inputs(3'b010, 16'hFFFF, 16'd0,    16'hFFFF);
        check_valid("spk=010                         -> valid=1", winner_valid, 1'b1);
        check_idx  ("spk=010, mem=[0xFFFF,0,0xFFFF] -> idx=1",  winner_idx,   IDX_W'(1));
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
        $dumpfile("tb_WTA.vcd");
        $dumpvars(0, tb_WTA);
    end

endmodule