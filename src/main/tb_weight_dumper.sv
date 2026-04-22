`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_weight_dumper
// Description: Simple testbench for weight_dumper.
//   Purely combinational: packs w_syn[j][i] into w_parallel_out at byte offset
//   (j*(N_INPUTS+FEEDBACK) + i)*8. No clock needed for correctness; a clock is
//   included only so $dumpvars produces a useful trace.
//////////////////////////////////////////////////////////////////////////////////

module tb_weight_dumper ();

    localparam int N_INPUTS  = 3;
    localparam int N_OUTPUTS = 2;
    localparam int FEEDBACK  = 1;
    localparam int ROW_LEN   = N_INPUTS + FEEDBACK;   // 4
    localparam int TOTAL     = ROW_LEN * N_OUTPUTS;   // 8 bytes

    logic       clk = 0;
    logic       rst;
    logic       en;
    logic [7:0] adr;
    logic [7:0] w_syn [N_OUTPUTS-1:0][ROW_LEN-1:0];
    logic [TOTAL*8-1:0] w_parallel_out;

    always #5 clk = ~clk;

    weight_dumper #(
        .N_INPUTS(N_INPUTS), .N_OUTPUTS(N_OUTPUTS), .FEEDBACK(FEEDBACK)
    ) dut (
        .clk(clk), .rst(rst), .en(en), .adr(adr),
        .w_syn(w_syn), .w_parallel_out(w_parallel_out)
    );

    int pass_count = 0, fail_count = 0;

    task automatic check(input string label, input logic cond);
        if (cond) begin $display("  PASS  %s", label); pass_count++; end
        else       begin $display("  FAIL  %s", label); fail_count++; end
    endtask

    // Extract the byte at logical index (j*ROW_LEN + i) from w_parallel_out
    function automatic logic [7:0] extract_byte(input int j, input int i);
        int idx;
        idx = (j*ROW_LEN + i) * 8;
        return w_parallel_out[idx +: 8];
    endfunction

    initial begin
        rst = 1'b0; en = 1'b0; adr = 8'd0;

        // Initialise matrix to zeros
        for (int j = 0; j < N_OUTPUTS; j++)
            for (int i = 0; i < ROW_LEN; i++)
                w_syn[j][i] = 8'd0;

        #1;

        // ==================================================================
        // TEST 1: All zeros in → all zeros out
        // ==================================================================
        $display("\n[%0t] TEST 1: zero matrix → zero parallel_out", $time);
        #1;
        check("w_parallel_out == 0", w_parallel_out === {TOTAL*8{1'b0}});

        // ==================================================================
        // TEST 2: Single non-zero at w_syn[0][0]
        //   Byte offset 0 → low byte of w_parallel_out
        // ==================================================================
        $display("\n[%0t] TEST 2: w_syn[0][0]=0xAB at byte 0", $time);
        w_syn[0][0] = 8'hAB;
        #1;
        check("byte[0] == 0xAB", extract_byte(0, 0) === 8'hAB);
        check("byte[1] == 0x00", extract_byte(0, 1) === 8'h00);

        // ==================================================================
        // TEST 3: w_syn[0][ROW_LEN-1] maps to byte (ROW_LEN-1)
        // ==================================================================
        $display("\n[%0t] TEST 3: w_syn[0][%0d]=0xCD at byte %0d",
                 $time, ROW_LEN-1, ROW_LEN-1);
        w_syn[0][ROW_LEN-1] = 8'hCD;
        #1;
        check("byte[ROW_LEN-1] == 0xCD", extract_byte(0, ROW_LEN-1) === 8'hCD);

        // ==================================================================
        // TEST 4: w_syn[1][0] maps to byte ROW_LEN (start of row 1)
        // ==================================================================
        $display("\n[%0t] TEST 4: w_syn[1][0]=0xEF at byte %0d", $time, ROW_LEN);
        w_syn[1][0] = 8'hEF;
        #1;
        check("byte[ROW_LEN] == 0xEF", extract_byte(1, 0) === 8'hEF);

        // ==================================================================
        // TEST 5: Fill full matrix with unique values, verify every byte
        //   w_syn[j][i] = j*16 + i
        // ==================================================================
        $display("\n[%0t] TEST 5: full-matrix pattern check", $time);
        for (int j = 0; j < N_OUTPUTS; j++)
            for (int i = 0; i < ROW_LEN; i++)
                w_syn[j][i] = 8'(j*16 + i);
        #1;
        begin
            logic all_match;
            all_match = 1'b1;
            for (int j = 0; j < N_OUTPUTS; j++)
                for (int i = 0; i < ROW_LEN; i++)
                    if (extract_byte(j, i) !== 8'(j*16 + i)) all_match = 1'b0;
            check("every byte matches w_syn[j][i]", all_match);
        end

        // ==================================================================
        $display("\n[%0t] ===== Testbench complete: %0d passed, %0d failed =====",
                 $time, pass_count, fail_count);
        if (fail_count == 0) $display("[%0t] ALL TESTS PASSED", $time);
        else                 $display("[%0t] %0d TEST(S) FAILED", $time, fail_count);
        $finish;
    end

    initial begin
        $dumpfile("tb_weight_dumper.vcd");
        $dumpvars(0, tb_weight_dumper);
    end

endmodule
