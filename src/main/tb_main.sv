`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_main
// Description: System-level testbench for main.sv.
//   Drives the DUT only through its real ports (CLK100MHZ, uart_txd_in,
//   btn_reset, uart_rxd_out) and checks that the UART -> verifier -> fifo ->
//   master -> {weight_loader, spike_loader, dopamine_loader} pipeline pushes
//   the right values into the SNN core.
//
//   Tests:
//     1.  After the auto power-on reset, w_syn == W_INIT everywhere.
//     2.  CMD_INIT (0) loads a 128-byte weight ramp into w_syn.
//         Diagnostic: prints up to the first 5 mismatches with actual/expected.
//     3.  CMD_SPIKE (1) loads a sparse spiketrain into the SNN.
//     4.  CMD_DOPAMINE (2) drives the right dopamine value AND pulses reward_en
//         while master_address == DOP_ADR (sampled by a concurrent watcher
//         since the dopamine pulse is much shorter than the UART packet).
//     5.  btn_reset clears volatile SNN state (spiketrain, spk_out).
//
//   The fletcher-16 (mod 255) checksum required by the protocol is computed
//   on the fly in flet16(), so tests don't carry magic checksum constants.
//
//   The end-to-end SNN-spikes-on-stimulus path is intentionally NOT tested
//   here; tb_SNN_core.sv covers it with parameters tuned so spikes are
//   actually reachable, while main.sv defaults (DECAY=256, THRESHOLD=1024)
//   make a single weighted input insufficient to fire.
//////////////////////////////////////////////////////////////////////////////////

module tb_main ();

    // --------------------------------------------------------------------------
    // Defaults of main.sv -- must stay in sync with main's own params.
    // --------------------------------------------------------------------------
    localparam int N_INPUTS  = 31;
    localparam int N_OUTPUTS = 4;
    localparam int FEEDBACK  = 1;
    localparam int W_MIN     = 40;
    localparam int W_MAX     = 254;
    localparam int W_INIT    = (W_MIN + W_MAX) / 2;     // 131
    localparam int ROW_LEN   = N_INPUTS + FEEDBACK;     // 32
    localparam int WEIGHT_N  = ROW_LEN * N_OUTPUTS;     // 128
    localparam int N_SPIKE_BYTES = (N_INPUTS + 2) / 3;  // 11
    localparam int DOP_ADR   = 199;

    // 100 MHz clock, BAUD ratio 400 -> 4000 ns per UART bit, 40000 ns per byte.
    localparam int BAUD_RATIO    = 400;
    localparam int BIT_PERIOD_NS = BAUD_RATIO * 10;

    // --------------------------------------------------------------------------
    // DUT I/O
    // --------------------------------------------------------------------------
    logic clk = 1'b0;
    logic rx  = 1'b1;       // UART idle = high
    logic btn_reset = 1'b0;
    wire  tx;

    main dut (
        .CLK100MHZ  (clk),
        .uart_txd_in(rx),
        .uart_rxd_out(tx),
        .btn_reset  (btn_reset)
    );

    always #5 clk = ~clk;

    // --------------------------------------------------------------------------
    // Pass / fail bookkeeping
    // --------------------------------------------------------------------------
    int pass_count = 0, fail_count = 0;

    task automatic check(input string label, input logic cond);
        if (cond) begin $display("  PASS  %s", label); pass_count++; end
        else      begin $display("  FAIL  %s", label); fail_count++; end
    endtask

    // --------------------------------------------------------------------------
    // UART byte sender (LSB first, 1 start + 8 data + 1 stop)
    // --------------------------------------------------------------------------
    task automatic send_byte(input byte unsigned d);
        rx = 1'b0;                       // start bit
        #(BIT_PERIOD_NS);
        for (int i = 0; i < 8; i++) begin
            rx = d[i];                   // LSB first
            #(BIT_PERIOD_NS);
        end
        rx = 1'b1;                       // stop bit
        #(BIT_PERIOD_NS);
    endtask

    // --------------------------------------------------------------------------
    // Fletcher-16 with MODULO=255 -- matches fletcher.sv exactly.
    // First byte returned (MSB of the 16-bit result) is checksum_1 / sum_1.
    // --------------------------------------------------------------------------
    function automatic logic [15:0] flet16(input byte unsigned q[$]);
        int s1, s2;
        s1 = 0; s2 = 0;
        foreach (q[i]) begin
            s1 += q[i];           if (s1 >= 255) s1 -= 255;
            s2 += s1;             if (s2 >= 255) s2 -= 255;
        end
        return {s1[7:0], s2[7:0]};
    endfunction

    // --------------------------------------------------------------------------
    // Send a full protocol packet: SOF | CMD | LEN | DATA[..] | SUM1 | SUM2
    // --------------------------------------------------------------------------
    task automatic send_packet(input byte unsigned cmd, input byte unsigned d[$]);
        byte unsigned   q[$];
        logic [15:0]    sum;
        q.push_back(8'hFF);
        q.push_back(cmd);
        q.push_back(byte'(d.size()));
        foreach (d[i]) q.push_back(d[i]);
        sum = flet16(q);

        send_byte(8'hFF);
        send_byte(cmd);
        send_byte(byte'(d.size()));
        foreach (d[i]) send_byte(d[i]);
        send_byte(sum[15:8]);   // checksum_1
        send_byte(sum[7:0]);    // checksum_2
    endtask

    // --------------------------------------------------------------------------
    // (neuron j, input i) -> linear weight address used by master.sv
    // --------------------------------------------------------------------------
    function automatic int weight_idx(input int j, input int i);
        return j * ROW_LEN + i;
    endfunction

    // --------------------------------------------------------------------------
    // Build one byte of the spike payload for a given chunk index.
    // spike_loader packs MSB-first: chunk c covers spiketrain bits
    // [TOTAL-1 - 3c : TOTAL-3c-3], with byte bits[5:4]=hi, [3:2]=mid, [1:0]=lo,
    // and pairs must be 2'b11 (set) or 2'b00 (clear) to be accepted.
    // --------------------------------------------------------------------------
    function automatic byte unsigned spike_byte(input int chunk,
                                                input logic [N_INPUTS-1:0] train);
        int hi_bit, mid_bit, lo_bit;
        byte unsigned v;
        hi_bit  = (N_INPUTS-1) - 3*chunk;
        mid_bit = hi_bit - 1;
        lo_bit  = hi_bit - 2;
        v = 8'h00;
        if (hi_bit  >= 0 && train[hi_bit])  v[5:4] = 2'b11;
        if (mid_bit >= 0 && train[mid_bit]) v[3:2] = 2'b11;
        if (lo_bit  >= 0 && train[lo_bit])  v[1:0] = 2'b11;
        return v;
    endfunction

    // --------------------------------------------------------------------------
    // Stimulus
    // --------------------------------------------------------------------------
    byte unsigned init_data[$];
    byte unsigned spike_data[$];
    byte unsigned dop_data[$];

    logic [N_INPUTS-1:0] spike_pattern;
    logic                ok;
    int                  mismatches;

    // Test-5 shared state between sender and watcher.
    logic       saw_reward_en;
    logic [3:0] sampled_dop;
    logic       dop_done;

    initial begin
        // Idle UART, release btn_reset, wait through the auto power-on reset window.
        rx = 1'b1;
        btn_reset = 1'b0;
        repeat (200) begin @(posedge clk); #1; end

        // ==================================================================
        // TEST 1: post-reset weights are W_INIT everywhere
        // ==================================================================
        $display("\n[%0t] TEST 1: w_syn == W_INIT after auto power-on reset", $time);
        ok = 1'b1;
        for (int j = 0; j < N_OUTPUTS; j++)
            for (int i = 0; i < ROW_LEN; i++)
                if (dut.w_syn[j][i] !== 8'(W_INIT)) ok = 1'b0;
        check("all w_syn == W_INIT", ok);

        // ==================================================================
        // TEST 2: CMD_INIT loads a deterministic ramp into w_syn
        // ==================================================================
        // Values must stay inside [W_MIN, W_MAX]: synapse_core clamps w_next
        // to that band every cycle, and main.sv has both weight_loader and
        // SNN_core driving the same w_next net -- out-of-band loads get
        // overwritten by the clamp, not by the loader.
        $display("\n[%0t] TEST 2: CMD_INIT writes weight matrix", $time);
        init_data.delete();
        for (int k = 0; k < WEIGHT_N; k++)
            init_data.push_back(byte'(W_MIN + k));         // 8..135, all in range
        send_packet(8'd0, init_data);
        // Master streams 128 addresses then INIT_WAIT->IDLE; allow plenty of margin.
        repeat (400) begin @(posedge clk); #1; end

        ok = 1'b1;
        mismatches = 0;
        for (int j = 0; j < N_OUTPUTS; j++)
            for (int i = 0; i < ROW_LEN; i++) begin
                automatic int idx = weight_idx(j, i);
                if (dut.w_syn[j][i] !== init_data[idx]) begin
                    ok = 1'b0;
                    if (mismatches < 5)
                        $display("    mismatch w_syn[%0d][%0d] = %0d (expected %0d, adr=%0d)",
                                 j, i, dut.w_syn[j][i], init_data[idx], idx);
                    mismatches++;
                end
            end
        $display("    total mismatches: %0d / %0d", mismatches, WEIGHT_N);
        check("w_syn matches init payload",     ok);
        check("w_syn[0][0]  == W_MIN",          dut.w_syn[0][0]  === 8'(W_MIN));
        check("w_syn[0][31] == W_MIN+31",       dut.w_syn[0][31] === 8'(W_MIN + 31));
        check("w_syn[3][31] == W_MIN+127",      dut.w_syn[3][31] === 8'(W_MIN + 127));

        // ==================================================================
        // TEST 3: CMD_SPIKE pushes the spiketrain into the SNN core
        // ==================================================================
        $display("\n[%0t] TEST 3: CMD_SPIKE updates spiketrain", $time);
        spike_pattern             = '0;
        spike_pattern[0]          = 1'b1;
        spike_pattern[5]          = 1'b1;
        spike_pattern[10]         = 1'b1;
        spike_pattern[15]         = 1'b1;
        spike_pattern[N_INPUTS-1] = 1'b1;

        spike_data.delete();
        for (int b = 0; b < N_SPIKE_BYTES; b++)
            spike_data.push_back(spike_byte(b, spike_pattern));
        send_packet(8'd1, spike_data);
        repeat (400) begin @(posedge clk); #1; end

        check("spiketrain matches programmed bits", dut.spiketrain === spike_pattern);

        // --- spike pattern 2: all inputs firing ---
        $display("\n[%0t] TEST 3b: CMD_SPIKE all-ones spiketrain", $time);
        spike_pattern = '1;

        spike_data.delete();
        for (int b = 0; b < N_SPIKE_BYTES; b++)
            spike_data.push_back(spike_byte(b, spike_pattern));
        send_packet(8'd1, spike_data);
        repeat (400) begin @(posedge clk); #1; end

        check("spiketrain all-ones", dut.spiketrain === spike_pattern);

        // --- spike pattern 3: even-indexed inputs only ---
        $display("\n[%0t] TEST 3c: CMD_SPIKE even-index spiketrain", $time);
        spike_pattern = '0;
        for (int i = 0; i < N_INPUTS; i += 2)
            spike_pattern[i] = 1'b1;

        spike_data.delete();
        for (int b = 0; b < N_SPIKE_BYTES; b++)
            spike_data.push_back(spike_byte(b, spike_pattern));
        send_packet(8'd1, spike_data);
        repeat (400) begin @(posedge clk); #1; end

        check("spiketrain even-indexed neurons", dut.spiketrain === spike_pattern);

        // --- spike pattern 4: clear all spikes ---
        $display("\n[%0t] TEST 3d: CMD_SPIKE all-zeros (clear) spiketrain", $time);
        spike_pattern = '0;

        spike_data.delete();
        for (int b = 0; b < N_SPIKE_BYTES; b++)
            spike_data.push_back(spike_byte(b, spike_pattern));
        send_packet(8'd1, spike_data);
        repeat (400) begin @(posedge clk); #1; end

        check("spiketrain cleared via CMD_SPIKE", dut.spiketrain === spike_pattern);

        // ==================================================================
        // TEST 4: CMD_DOPAMINE drives dopamine + reward_en at adr==DOP_ADR.
        //   The dopamine_loader is purely combinational on master_address,
        //   so the pulse only lasts while master is in DOPAMINE_WRITE.
        //   We launch the sampler in parallel with send_packet so we don't
        //   miss it.
        // ==================================================================
        $display("\n[%0t] TEST 4: CMD_DOPAMINE updates dopamine / reward_en", $time);

        // ----- positive dopamine -----
        saw_reward_en = 1'b0;
        sampled_dop   = '0;
        dop_done      = 1'b0;
        dop_data.delete();
        dop_data.push_back(8'h04);                       // +4

        fork
            begin : watch_dop_pos
                while (!dop_done) begin
                    @(posedge clk); #1;
                    if (dut.master_address == 8'(DOP_ADR)) begin
                        if (dut.reward_en) saw_reward_en = 1'b1;
                        sampled_dop = dut.dopamine;
                    end
                end
            end
            begin : drive_dop_pos
                send_packet(8'd2, dop_data);
                repeat (400) begin @(posedge clk); #1; end
                dop_done = 1'b1;
            end
        join

        check("dopamine == +4 while adr==DOP_ADR",       sampled_dop === 4'sd4);
        check("reward_en pulsed during dopamine write",  saw_reward_en);

        // ----- negative dopamine -----
        saw_reward_en = 1'b0;
        sampled_dop   = '0;
        dop_done      = 1'b0;
        dop_data[0]   = 8'hFC;                           // low nibble = -4

        fork
            begin : watch_dop_neg
                while (!dop_done) begin
                    @(posedge clk); #1;
                    if (dut.master_address == 8'(DOP_ADR)) begin
                        if (dut.reward_en) saw_reward_en = 1'b1;
                        sampled_dop = dut.dopamine;
                    end
                end
            end
            begin : drive_dop_neg
                send_packet(8'd2, dop_data);
                repeat (400) begin @(posedge clk); #1; end
                dop_done = 1'b1;
            end
        join

        check("dopamine == -4 while adr==DOP_ADR",        sampled_dop === -4'sd4);
        check("reward_en pulsed for negative dopamine",   saw_reward_en);

        // ==================================================================
        // TEST 5: btn_reset clears volatile SNN state
        // ==================================================================
        $display("\n[%0t] TEST 5: btn_reset clears spiketrain and spk_out", $time);
        btn_reset = 1'b1;
        repeat (10) begin @(posedge clk); #1; end
        btn_reset = 1'b0;
        repeat (200) begin @(posedge clk); #1; end

        check("spiketrain cleared after reset", dut.spiketrain === '0);
        check("spk_out cleared after reset",     dut.spk_out  === '0);

        // ==================================================================
        // Summary
        // ==================================================================
        $display("\n[%0t] ===== Testbench complete: %0d passed, %0d failed =====",
                 $time, pass_count, fail_count);
        if (fail_count == 0) $display("[%0t] ALL TESTS PASSED", $time);
        else                 $display("[%0t] %0d TEST(S) FAILED", $time, fail_count);

        $finish;
    end

    // --------------------------------------------------------------------------
    // Waveform dump
    // --------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_main.vcd");
        $dumpvars(0, tb_main);
    end

endmodule
