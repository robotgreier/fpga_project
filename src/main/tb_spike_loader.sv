`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_spike_loader
// Description: Simple testbench for spike_loader.
//   Loads 3-bit spike chunks via (data, adr) when adr in [ADR_MIN, ADR_MAX].
//   spiketrain auto-commits one cycle after the last chunk (LAST_CHUNK) is written.
//   Each byte encodes 3 spikes in bit-pairs: 2'b11 = 1, 2'b00 = 0, else invalid.
//////////////////////////////////////////////////////////////////////////////////

module tb_spike_loader ();

    localparam int N_INPUTS  = 31;
    localparam int ADR_MIN   = 200;
    localparam int N_CHUNKS  = (N_INPUTS + 2) / 3;       // 11
    localparam int ADR_MAX   = ADR_MIN + N_CHUNKS - 1;   // 210

    logic                  clk = 0;
    logic                  rst;
    logic [7:0]            data;
    logic [7:0]            adr;
    logic [N_INPUTS-1:0]   spiketrain;

    always #5 clk = ~clk;

    spike_loader #(.N_INPUTS(N_INPUTS)) dut (
        .clk(clk), .rst(rst),
        .data(data), .adr(adr),
        .spiketrain(spiketrain)
    );

    int pass_count = 0, fail_count = 0;

    task automatic check(input string label, input logic cond);
        if (cond) begin $display("  PASS  %s", label); pass_count++; end
        else       begin $display("  FAIL  %s", label); fail_count++; end
    endtask

    // Drive (data, adr) for one cycle, then park adr out of range
    task automatic load(input logic [7:0] d, input logic [7:0] a);
        @(negedge clk);
        data = d; adr = a;
        @(posedge clk); #1;
        @(negedge clk);
        adr = 8'hFF;
    endtask

    // Stream a full frame: byte k goes to address ADR_MIN+k.
    // After the last chunk write, spiketrain commits one cycle later.
    task automatic load_frame(input logic [7:0] bytes [N_CHUNKS]);
        for (int k = 0; k < N_CHUNKS; k++)
            load(bytes[k], 8'(ADR_MIN + k));
        // Wait one extra cycle for the commit register to update spiketrain
        @(posedge clk); #1;
    endtask

    initial begin
        logic [7:0] frame [N_CHUNKS];
        rst = 1'b1; data = 8'd0; adr = 8'hFF;

        // Reset for 2 cycles
        @(posedge clk); @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;

        // ==================================================================
        // TEST 1: After reset, spiketrain is zero
        // ==================================================================
        $display("\n[%0t] TEST 1: spiketrain == 0 after reset", $time);
        check("spiketrain==0", spiketrain === {N_INPUTS{1'b0}});

        // ==================================================================
        // TEST 2: Partial frame does NOT commit
        //   Write only the first chunk; spiketrain should remain 0.
        // ==================================================================
        $display("\n[%0t] TEST 2: partial frame does not commit", $time);
        load(8'b00_11_11_11, 8'd200);
        @(posedge clk); #1;
        check("spiketrain still 0 after 1 chunk", spiketrain === {N_INPUTS{1'b0}});

        // ==================================================================
        // TEST 3: Full frame commits on last chunk
        //   chunk 0 = all ones (3'b111) → spiketrain[30:28]
        //   chunk 1 = 3'b101            → spiketrain[27:25]
        //   chunks 2..LAST = all zeros
        // ==================================================================
        $display("\n[%0t] TEST 3: full frame → spiketrain commits", $time);
        @(negedge clk); rst = 1'b1;
        @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;

        frame[0] = 8'b00_11_11_11;   // 3'b111
        frame[1] = 8'b00_11_00_11;   // 3'b101
        for (int k = 2; k < N_CHUNKS; k++) frame[k] = 8'b00_00_00_00;
        load_frame(frame);

        check("spiketrain[30:28] == 3'b111", spiketrain[30:28] === 3'b111);
        check("spiketrain[27:25] == 3'b101", spiketrain[27:25] === 3'b101);
        check("spiketrain[24:0]  == 0",       spiketrain[24:0]  === 25'd0);

        // ==================================================================
        // TEST 4: Invalid pair → that chunk is dropped (rest of frame still commits)
        // ==================================================================
        $display("\n[%0t] TEST 4: invalid pair is ignored", $time);
        @(negedge clk); rst = 1'b1;
        @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;

        frame[0] = 8'b00_11_11_11;   // valid: 3'b111
        frame[1] = 8'b00_01_00_00;   // invalid pair → write skipped
        for (int k = 2; k < N_CHUNKS; k++) frame[k] = 8'b00_00_00_00;
        load_frame(frame);

        check("spiketrain[30:28] == 3'b111 (valid)", spiketrain[30:28] === 3'b111);
        check("spiketrain[27:25] == 0 (invalid skipped)", spiketrain[27:25] === 3'b000);

        // ==================================================================
        // TEST 5: Reset clears spiketrain
        // ==================================================================
        $display("\n[%0t] TEST 5: reset clears spiketrain", $time);
        @(negedge clk); rst = 1'b1;
        @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;
        check("spiketrain == 0 after reset", spiketrain === {N_INPUTS{1'b0}});

        // ==================================================================
        $display("\n[%0t] ===== Testbench complete: %0d passed, %0d failed =====",
                 $time, pass_count, fail_count);
        if (fail_count == 0) $display("[%0t] ALL TESTS PASSED", $time);
        else                 $display("[%0t] %0d TEST(S) FAILED", $time, fail_count);
        $finish;
    end

    initial begin
        $dumpfile("tb_spike_loader.vcd");
        $dumpvars(0, tb_spike_loader);
    end

endmodule
