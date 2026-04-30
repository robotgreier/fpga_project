`timescale 1ns / 1ps

module tb_WTA ();

    localparam int N_OUTPUTS = 3;
    localparam int IDX_W     = $clog2(N_OUTPUTS);

    logic [N_OUTPUTS-1:0]       spk;
    logic [N_OUTPUTS-1:0][15:0] pre_reset_mem;
    logic [IDX_W-1:0]           winner_idx;
    logic                       winner_valid;

    WTA #(.N_OUTPUTS(N_OUTPUTS)) dut (
        .spk          (spk),
        .pre_reset_mem(pre_reset_mem),
        .winner_idx   (winner_idx),
        .winner_valid (winner_valid)
    );

    int pass_count = 0;
    int fail_count = 0;

    task automatic apply_inputs(
        input logic [N_OUTPUTS-1:0] spk_val,
        input logic [15:0]          mem0, mem1, mem2
    );
        spk              = spk_val;
        pre_reset_mem[0] = mem0;
        pre_reset_mem[1] = mem1;
        pre_reset_mem[2] = mem2;
        #10;
        $display("[%0t ns]  spk=%03b  mem=[%0d,%0d,%0d]  valid=%0b  idx=%0d",
                 $time, spk, pre_reset_mem[0], pre_reset_mem[1], pre_reset_mem[2],
                 winner_valid, winner_idx);
    endtask

    // Always checks winner_valid; also checks winner_idx when exp_valid=1.
    task automatic check_winner(
        input string            label,
        input logic             exp_valid,
        input logic [IDX_W-1:0] exp_idx
    );
        if (winner_valid !== exp_valid) begin
            $display("  FAIL  %s : winner_valid got %0b, expected %0b", label, winner_valid, exp_valid);
            fail_count++;
        end else begin
            $display("  PASS  %s : winner_valid=%0b", label, winner_valid);
            pass_count++;
        end
        if (exp_valid) begin
            if (winner_idx !== exp_idx) begin
                $display("  FAIL  %s : winner_idx got %0d, expected %0d", label, winner_idx, exp_idx);
                fail_count++;
            end else begin
                $display("  PASS  %s : winner_idx=%0d", label, winner_idx);
                pass_count++;
            end
        end
    endtask

    initial begin
        $display("\n[%0t] TEST 1: No spikes -- winner_valid must be 0", $time);
        apply_inputs(3'b000, 16'd50,   16'd200,  16'd100);
        check_winner("spk=000, mem=[50,200,100]",     1'b0, IDX_W'(0));
        apply_inputs(3'b000, 16'd0,    16'd0,    16'd0);
        check_winner("spk=000, mem=[0,0,0]",          1'b0, IDX_W'(0));
        apply_inputs(3'b000, 16'hFFFF, 16'hFFFF, 16'hFFFF);
        check_winner("spk=000, mem=[max,max,max]",    1'b0, IDX_W'(0));

        $display("\n[%0t] TEST 2: Single spike -- forced winner", $time);
        apply_inputs(3'b001, 16'd10,  16'd500, 16'd900);
        check_winner("spk=001, mem=[10,500,900]",     1'b1, IDX_W'(0));
        apply_inputs(3'b010, 16'd900, 16'd10,  16'd500);
        check_winner("spk=010, mem=[900,10,500]",     1'b1, IDX_W'(1));
        apply_inputs(3'b100, 16'd900, 16'd500, 16'd10);
        check_winner("spk=100, mem=[900,500,10]",     1'b1, IDX_W'(2));

        $display("\n[%0t] TEST 3: Multiple spikes -- highest spiking membrane wins", $time);
        apply_inputs(3'b011, 16'd300, 16'd200, 16'd900);
        check_winner("spk=011, mem=[300,200,900]",    1'b1, IDX_W'(0));
        apply_inputs(3'b101, 16'd200, 16'd900, 16'd300);
        check_winner("spk=101, mem=[200,900,300]",    1'b1, IDX_W'(2));
        apply_inputs(3'b110, 16'd900, 16'd200, 16'd300);
        check_winner("spk=110, mem=[900,200,300]",    1'b1, IDX_W'(2));

        $display("\n[%0t] TEST 4: All neurons spike -- argmax over all", $time);
        apply_inputs(3'b111, 16'd100, 16'd300, 16'd200);
        check_winner("spk=111, mem=[100,300,200]",    1'b1, IDX_W'(1));
        apply_inputs(3'b111, 16'd100, 16'd200, 16'd300);
        check_winner("spk=111, mem=[100,200,300]",    1'b1, IDX_W'(2));
        apply_inputs(3'b111, 16'd300, 16'd200, 16'd100);
        check_winner("spk=111, mem=[300,200,100]",    1'b1, IDX_W'(0));

        $display("\n[%0t] TEST 5: Tie-breaking -- highest index wins on equal membrane", $time);
        apply_inputs(3'b111, 16'd100, 16'd100, 16'd100);
        check_winner("spk=111, mem=[100,100,100]",    1'b1, IDX_W'(2));
        apply_inputs(3'b111, 16'd100, 16'd100, 16'd50);
        check_winner("spk=111, mem=[100,100,50]",     1'b1, IDX_W'(1));
        apply_inputs(3'b111, 16'd100, 16'd50,  16'd100);
        check_winner("spk=111, mem=[100,50,100]",     1'b1, IDX_W'(2));
        apply_inputs(3'b011, 16'd100, 16'd100, 16'd0);
        check_winner("spk=011, mem=[100,100,0]",      1'b1, IDX_W'(1));

        $display("\n[%0t] TEST 6: Boundary -- maximum membrane (0xFFFF)", $time);
        apply_inputs(3'b001, 16'hFFFF, 16'd0,    16'd0);
        check_winner("spk=001, mem=[0xFFFF,0,0]",     1'b1, IDX_W'(0));
        apply_inputs(3'b110, 16'd0,    16'hFFFF, 16'hFFFF);
        check_winner("spk=110, mem=[0,0xFFFF,0xFFFF]", 1'b1, IDX_W'(2));
        apply_inputs(3'b010, 16'hFFFF, 16'd0,    16'hFFFF);
        check_winner("spk=010, mem=[0xFFFF,0,0xFFFF]", 1'b1, IDX_W'(1));

        $display("\n[%0t] ===== Testbench complete: %0d passed, %0d failed =====",
                 $time, pass_count, fail_count);
        if (fail_count == 0)
            $display("[%0t] ALL TESTS PASSED", $time);
        else
            $display("[%0t] %0d TEST(S) FAILED -- see FAIL lines above", $time, fail_count);
        $finish;
    end

    initial begin
        $dumpfile("tb_WTA.vcd");
        $dumpvars(0, tb_WTA);
    end

endmodule
