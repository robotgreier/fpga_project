`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_spike_loader
// Description: Simple testbench for spike_loader.
//   Loads 3-bit spike chunks via (data, adr) when adr in [200,254], latches
//   full spiketrain on done.
//   Each byte encodes 3 spikes in bit-pairs: 2'b11 = 1, 2'b00 = 0, else invalid.
//////////////////////////////////////////////////////////////////////////////////

module tb_spike_loader ();

    localparam int N_INPUTS = 31;

    logic                  clk = 0;
    logic                  rst;
    logic [7:0]            data;
    logic [7:0]            adr;
    logic                  done;
    logic [N_INPUTS-1:0]   spiketrain;

    always #5 clk = ~clk;

    spike_loader #(.N_INPUTS(N_INPUTS)) dut (
        .clk(clk), .rst(rst),
        .data(data), .adr(adr), .done(done),
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

    // Pulse done for one cycle to latch spiketrain
    task automatic pulse_done();
        @(negedge clk);
        done = 1'b1;
        @(posedge clk); #1;
        @(negedge clk);
        done = 1'b0;
    endtask

    initial begin
        rst = 1'b1; done = 1'b0; data = 8'd0; adr = 8'hFF;

        // Reset for 2 cycles
        @(posedge clk); @(posedge clk); #1;
        @(negedge clk); rst = 1'b0;

        // ==================================================================
        // TEST 1: After reset, spiketrain is zero
        // ==================================================================
        $display("\n[%0t] TEST 1: spiketrain == 0 after reset", $time);
        check("spiketrain==0", spiketrain === {N_INPUTS{1'b0}});

        // ==================================================================
        // TEST 2: Load one chunk (adr=0) with all three spikes = 1
        //   data = 8'b00_11_11_11 → 3 ones in top chunk
        //   spiketrain[30:28] should become 3'b111 after done
        // ==================================================================
        $display("\n[%0t] TEST 2: load 3 spikes into top chunk", $time);
        load(8'b00_11_11_11, 8'd200);
        pulse_done();
        check("spiketrain[30:28] == 3'b111", spiketrain[30:28] === 3'b111);
        check("other bits still 0",          spiketrain[27:0]  === 28'd0);

        // ==================================================================
        // TEST 3: Load second chunk (adr=1) with spike pattern 3'b101
        //   bit0 pair = 11 → 1, bit1 pair = 00 → 0, bit2 pair = 11 → 1
        //   data = 8'b00_11_00_11  → spk_temp = 3'b101
        //   spiketrain[27:25] should become 3'b101
        // ==================================================================
        $display("\n[%0t] TEST 3: load spikes 3'b101 into chunk 1", $time);
        load(8'b00_11_00_11, 8'd201);
        pulse_done();
        check("spiketrain[27:25] == 3'b101", spiketrain[27:25] === 3'b101);
        check("top chunk preserved",         spiketrain[30:28] === 3'b111);

        // ==================================================================
        // TEST 4: Invalid pair (not 00 / 11) → ignored (pair_valid = 0)
        // ==================================================================
        $display("\n[%0t] TEST 4: invalid pair is ignored", $time);
        load(8'b00_01_00_00, 8'd202);  // pair 01 invalid
        pulse_done();
        check("spiketrain[24:22] still 0", spiketrain[24:22] === 3'b000);

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
