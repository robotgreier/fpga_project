`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_weight_loader
// Description: Simple testbench for weight_loader.
//   Writes bytes into a weight matrix addressed by adr = j*(N_INPUTS+FEEDBACK)+i.
//   On reset all entries are W_INIT.
//////////////////////////////////////////////////////////////////////////////////

module tb_weight_loader ();

    localparam int N_INPUTS  = 4;
    localparam int N_OUTPUTS = 2;
    localparam int FEEDBACK  = 1;
    localparam int W_INIT    = 64;
    localparam int ROW_LEN   = N_INPUTS + FEEDBACK;   // 5

    logic       clk = 0;
    logic       rst;
    logic [7:0] data;
    logic [7:0] adr;
    logic [7:0] w_next [N_OUTPUTS-1:0][ROW_LEN-1:0];

    always #5 clk = ~clk;

    weight_loader #(
        .N_INPUTS(N_INPUTS), .N_OUTPUTS(N_OUTPUTS),
        .FEEDBACK(FEEDBACK), .W_INIT(W_INIT)
    ) dut (
        .clk(clk), .rst(rst),
        .data(data), .adr(adr), .w_next(w_next)
    );

    int pass_count = 0, fail_count = 0;

    task automatic check(input string label, input logic cond);
        if (cond) begin $display("  PASS  %s", label); pass_count++; end
        else       begin $display("  FAIL  %s", label); fail_count++; end
    endtask

    task automatic write_w(input logic [7:0] d, input logic [7:0] a);
        @(negedge clk);
        data = d; adr = a;
        @(posedge clk); #1;
        @(negedge clk);
        adr = 8'hFF;
    endtask

    initial begin
        rst = 1'b1; data = 8'd0; adr = 8'hFF;

        // Reset for 2 cycles
        @(posedge clk); @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;
        @(posedge clk); #1;

        // ==================================================================
        // TEST 1: After reset, every entry equals W_INIT
        // ==================================================================
        $display("\n[%0t] TEST 1: all weights == W_INIT after reset", $time);
        begin
            logic all_init;
            all_init = 1'b1;
            for (int j = 0; j < N_OUTPUTS; j++)
                for (int i = 0; i < ROW_LEN; i++)
                    if (w_next[j][i] !== 8'(W_INIT)) all_init = 1'b0;
            check("all w_next == W_INIT(64)", all_init);
        end

        // ==================================================================
        // TEST 2: Write single weight at adr=0 → w_next[0][0]
        // ==================================================================
        $display("\n[%0t] TEST 2: write adr=0 → w_next[0][0]", $time);
        write_w(8'd123, 8'd0);
        check("w_next[0][0] == 123", w_next[0][0] === 8'd123);
        check("w_next[0][1] still W_INIT", w_next[0][1] === 8'(W_INIT));

        // ==================================================================
        // TEST 3: Write adr = ROW_LEN → w_next[1][0] (start of row 1)
        // ==================================================================
        $display("\n[%0t] TEST 3: write adr=ROW_LEN → w_next[1][0]", $time);
        write_w(8'd200, 8'(ROW_LEN));
        check("w_next[1][0] == 200", w_next[1][0] === 8'd200);

        // ==================================================================
        // TEST 4: Write adr = ROW_LEN+2 → w_next[1][2]
        // ==================================================================
        $display("\n[%0t] TEST 4: write adr=ROW_LEN+2 → w_next[1][2]", $time);
        write_w(8'd55, 8'(ROW_LEN+2));
        check("w_next[1][2] == 55", w_next[1][2] === 8'd55);
        check("w_next[0][0] preserved (123)", w_next[0][0] === 8'd123);
        check("w_next[1][0] preserved (200)", w_next[1][0] === 8'd200);

        // ==================================================================
        // TEST 5: out-of-range adr → no write
        // ==================================================================
        $display("\n[%0t] TEST 5: adr out of range → no update", $time);
        @(negedge clk);
        data = 8'd99; adr = 8'd255;
        @(posedge clk); #1;
        check("w_next[0][0] unchanged (still 123)", w_next[0][0] === 8'd123);

        // ==================================================================
        // TEST 6: Reset reinitialises all entries to W_INIT
        // ==================================================================
        $display("\n[%0t] TEST 6: reset restores W_INIT everywhere", $time);
        @(negedge clk); rst = 1'b1;
        @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;
        @(posedge clk); #1;
        begin
            logic all_init;
            all_init = 1'b1;
            for (int j = 0; j < N_OUTPUTS; j++)
                for (int i = 0; i < ROW_LEN; i++)
                    if (w_next[j][i] !== 8'(W_INIT)) all_init = 1'b0;
            check("all w_next == W_INIT after rst", all_init);
        end

        // ==================================================================
        $display("\n[%0t] ===== Testbench complete: %0d passed, %0d failed =====",
                 $time, pass_count, fail_count);
        if (fail_count == 0) $display("[%0t] ALL TESTS PASSED", $time);
        else                 $display("[%0t] %0d TEST(S) FAILED", $time, fail_count);
        $finish;
    end

    initial begin
        $dumpfile("tb_weight_loader.vcd");
        $dumpvars(0, tb_weight_loader);
    end

endmodule
