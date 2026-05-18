`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: tb_SNN_core
// Description: Testbench for SNN_core.
//   DUT 0 (LEARNING_MODE=0): reset, silence, single-neuron spike, WTA, feedback.
//   DUT 1 (LEARNING_MODE=2, STDP):  LTP on causal pre→post; no change w/ reward_en=0.
//   DUT 2 (LEARNING_MODE=1, R-STDP): LTP w/ positive dopamine; LTD w/ negative.
//////////////////////////////////////////////////////////////////////////////////

module tb_SNN_core ();

    // =========================================================================
    // Shared 100 MHz clock
    // =========================================================================
    logic clk = 1'b0;
    always #5 clk = ~clk;

    // run=1 for all DUTs: these are neural-behavior unit tests, not gating tests
    logic run = 1'b1;

    // =========================================================================
    // Pass / fail bookkeeping
    // =========================================================================
    int pass_count = 0, fail_count = 0;

    task automatic check(input string label, input logic cond);
        if (cond) begin $display("  PASS  %s", label); pass_count++; end
        else       begin $display("  FAIL  %s", label); fail_count++; end
    endtask

    // =========================================================================
    // DUT 0 – LEARNING_MODE=0  (N_INPUTS=4, N_OUTPUTS=3, FEEDBACK=1)
    //   THRESHOLD=512, DECAY=64 → w=200 reaches threshold in ~4 cycles
    // =========================================================================
    localparam int D0_NI  = 4;
    localparam int D0_NO  = 3;
    localparam int D0_FB  = 1;
    localparam int D0_NIT = D0_NI + D0_FB;   // 5

    logic              d0_rst;
    logic [D0_NI-1:0]  d0_pre;
    logic signed [3:0] d0_dop = 4'sd0;
    logic              d0_ren = 1'b0;
    logic [7:0]        d0_wsyn [D0_NO-1:0][D0_NIT-1:0];
    logic [D0_NO-1:0]  d0_spk;
    logic [$clog2(D0_NO)-1:0] d0_widx;
    logic [7:0]        d0_wnxt [D0_NO-1:0][D0_NIT-1:0];

    SNN_core #(
        .N_INPUTS(D0_NI), .N_OUTPUTS(D0_NO), .FEEDBACK(D0_FB),
        .THRESHOLD(512), .DECAY(64), .RESET(0), .LEARNING_MODE(0)
    ) dut0 (
        .clk(clk), .run(run), .rst(d0_rst), .spiketrain(d0_pre), .dopamine(d0_dop),
        .reward_en(d0_ren), .w_syn(d0_wsyn),
        .spk_out(d0_spk), .winner_idx(d0_widx), .w_next(d0_wnxt)
    );

    task automatic d0_step(input logic [D0_NI-1:0] spk);
        @(negedge clk); d0_pre = spk; @(posedge clk); #1;
        $display("[%0t] d0  pre=%04b  spk=%03b  widx=%0d",
                 $time, d0_pre, d0_spk, d0_widx);
    endtask

    task automatic d0_reset();
        @(negedge clk); d0_rst = 1'b1; @(posedge clk); #1;
        @(negedge clk); d0_rst = 1'b0; @(posedge clk); #1;
    endtask

    // =========================================================================
    // DUT 1 – LEARNING_MODE=2 (STDP)   |  DUT 2 – LEARNING_MODE=1 (R-STDP)
    //   N_INPUTS=2, N_OUTPUTS=2, FEEDBACK=0
    //   THRESHOLD=128, DECAY=16 → w=80 reaches threshold in 2 cycles
    //   DW_POS=16, T_PRE/T_POST=4, LR_SHIFT=2
    //
    //   Spike cycle 1: elig_trace still 0 → delta_w=0 → w_next=w_syn
    //   Spike cycle 2: elig_trace=9 (LTP from previous post_edge, decayed)
    //                  → STDP : delta_w = 9>>>2 = 2  → w_next = 82
    //                  → R-STDP +4: delta_w = (9*4)>>>2 = 9 → w_next = 89
    //                  → R-STDP -4: delta_w = (9*-4)>>>2 = -9 → w_next = 71
    // =========================================================================
    localparam int DL_NI  = 2;
    localparam int DL_NO  = 2;
    localparam int DL_NIT = DL_NI;   // FEEDBACK=0, so 2

    // --- DUT 1 (STDP) ---
    logic              d1_rst;
    logic [DL_NI-1:0]  d1_pre;
    logic signed [3:0] d1_dop = 4'sd0;
    logic              d1_ren;
    logic [7:0]        d1_wsyn [DL_NO-1:0][DL_NIT-1:0];
    logic [DL_NO-1:0]  d1_spk;
    logic [$clog2(DL_NO)-1:0] d1_widx;
    logic [7:0]        d1_wnxt [DL_NO-1:0][DL_NIT-1:0];

    SNN_core #(
        .N_INPUTS(DL_NI), .N_OUTPUTS(DL_NO), .FEEDBACK(0),
        .THRESHOLD(128), .DECAY(16), .RESET(0),
        .DW_POS(16), .T_PRE(4), .T_POST(4), .LR_SHIFT(2),
        .W_MIN(8), .W_MAX(200), .LEARNING_MODE(2)
    ) dut1 (
        .clk(clk), .run(run), .rst(d1_rst), .spiketrain(d1_pre), .dopamine(d1_dop),
        .reward_en(d1_ren), .w_syn(d1_wsyn),
        .spk_out(d1_spk), .winner_idx(d1_widx), .w_next(d1_wnxt)
    );

    // --- DUT 2 (R-STDP) ---
    logic              d2_rst;
    logic [DL_NI-1:0]  d2_pre;
    logic signed [3:0] d2_dop;
    logic              d2_ren;
    logic [7:0]        d2_wsyn [DL_NO-1:0][DL_NIT-1:0];
    logic [DL_NO-1:0]  d2_spk;
    logic [$clog2(DL_NO)-1:0] d2_widx;
    logic [7:0]        d2_wnxt [DL_NO-1:0][DL_NIT-1:0];

    SNN_core #(
        .N_INPUTS(DL_NI), .N_OUTPUTS(DL_NO), .FEEDBACK(0),
        .THRESHOLD(128), .DECAY(16), .RESET(0),
        .DW_POS(16), .T_PRE(4), .T_POST(4), .LR_SHIFT(2),
        .W_MIN(8), .W_MAX(200), .LEARNING_MODE(1)
    ) dut2 (
        .clk(clk), .run(run), .rst(d2_rst), .spiketrain(d2_pre), .dopamine(d2_dop),
        .reward_en(d2_ren), .w_syn(d2_wsyn),
        .spk_out(d2_spk), .winner_idx(d2_widx), .w_next(d2_wnxt)
    );

    task automatic d1_step(input logic [DL_NI-1:0] spk);
        @(negedge clk); d1_pre = spk; @(posedge clk); #1;
        $display("[%0t] d1(STDP)   pre=%02b  spk=%02b  wnxt[0][0]=%0d",
                 $time, d1_pre, d1_spk, d1_wnxt[0][0]);
    endtask

    task automatic d1_reset();
        @(negedge clk); d1_rst = 1'b1; @(posedge clk); #1;
        @(negedge clk); d1_rst = 1'b0; @(posedge clk); #1;
    endtask

    task automatic d2_step(input logic [DL_NI-1:0] spk);
        @(negedge clk); d2_pre = spk; @(posedge clk); #1;
        $display("[%0t] d2(RSTDP)  pre=%02b  spk=%02b  wnxt[0][0]=%0d",
                 $time, d2_pre, d2_spk, d2_wnxt[0][0]);
    endtask

    task automatic d2_reset();
        @(negedge clk); d2_rst = 1'b1; @(posedge clk); #1;
        @(negedge clk); d2_rst = 1'b0; @(posedge clk); #1;
    endtask

    // =========================================================================
    // Module-level test tracker variables (reused each test, reset before use)
    // =========================================================================
    int   t_spk_c, t_win_c, t_sc;
    logic t_w_up, t_w_dn, t_w_chg;

    // =========================================================================
    // Stimulus
    // =========================================================================
    initial begin
        // Initialise all DUTs
        d0_rst = 1'b1; d0_pre = '0;
        d1_rst = 1'b1; d1_pre = '0; d1_ren = 1'b0;
        d2_rst = 1'b1; d2_pre = '0; d2_ren = 1'b0; d2_dop = 4'sd0;
        for (int j = 0; j < D0_NO; j++)
            for (int i = 0; i < D0_NIT; i++) d0_wsyn[j][i] = 8'd0;
        for (int j = 0; j < DL_NO; j++)
            for (int i = 0; i < DL_NIT; i++) begin
                d1_wsyn[j][i] = 8'd0;
                d2_wsyn[j][i] = 8'd0;
            end

        // Hold reset 2 cycles then release all
        @(posedge clk); #1; @(posedge clk); #1;
        d0_rst = 1'b0; d1_rst = 1'b0; d2_rst = 1'b0;

        // ==================================================================
        // TEST 1: Post-reset silence
        // ==================================================================
        $display("\n[%0t] TEST 1: post-reset silence", $time);
        repeat (2) d0_step('0);
        check("spk_out==0 after reset", d0_spk === 3'b000);

        // ==================================================================
        // TEST 2: No input, no spikes
        // ==================================================================
        $display("\n[%0t] TEST 2: no input, no spikes", $time);
        repeat (5) d0_step('0);
        check("silent with zero input", d0_spk === 3'b000);

        // ==================================================================
        // TEST 3: Neuron 0 spikes, winner_idx captured at spike cycle
        // ==================================================================
        $display("\n[%0t] TEST 3: neuron 0 spikes, winner_idx==0", $time);
        for (int j = 0; j < D0_NO; j++)
            for (int i = 0; i < D0_NIT; i++) d0_wsyn[j][i] = 8'd0;
        d0_wsyn[0][0] = 8'd200;
        d0_reset();
        t_spk_c = -1; t_win_c = -1;
        for (int c = 0; c < 10; c++) begin
            d0_step(4'b0001);
            if (d0_spk[0] && t_spk_c < 0) begin
                t_spk_c = c;
                t_win_c = int'(d0_widx);   // capture at spike cycle, not after loop
            end
        end
        check("neuron 0 spiked",          t_spk_c >= 0);
        check("winner_idx==0 at spike",   t_win_c == 0);
        check("neurons 1,2 silent",       (d0_spk & 3'b110) === 3'b000);

        // ==================================================================
        // TEST 4: Neuron 2 spikes, winner_idx captured at spike cycle
        //   (bug fix: reading winner_idx after the loop gives 0 (WTA default
        //    when no spike), not the value at the spike moment)
        // ==================================================================
        $display("\n[%0t] TEST 4: neuron 2 spikes, winner_idx==2", $time);
        for (int j = 0; j < D0_NO; j++)
            for (int i = 0; i < D0_NIT; i++) d0_wsyn[j][i] = 8'd0;
        d0_wsyn[2][2] = 8'd200;
        d0_reset();
        t_spk_c = -1; t_win_c = -1;
        for (int c = 0; c < 10; c++) begin
            d0_step(4'b0100);
            if (d0_spk[2] && t_spk_c < 0) begin
                t_spk_c = c;
                t_win_c = int'(d0_widx);
            end
        end
        check("neuron 2 spiked",          t_spk_c >= 0);
        check("winner_idx==2 at spike",   t_win_c == 2);

        // ==================================================================
        // TEST 5: WTA competition -- neuron 1 has higher weight, wins first
        // ==================================================================
        $display("\n[%0t] TEST 5: WTA -- neuron 1 wins (higher weight)", $time);
        for (int j = 0; j < D0_NO; j++)
            for (int i = 0; i < D0_NIT; i++) d0_wsyn[j][i] = 8'd0;
        d0_wsyn[0][0] = 8'd150;
        d0_wsyn[1][1] = 8'd250;
        d0_reset();
        t_win_c = -1;
        for (int c = 0; c < 15; c++) begin
            d0_step(4'b0011);
            if (|d0_spk && t_win_c < 0) t_win_c = int'(d0_widx);
        end
        check("at least one spike",            t_win_c >= 0);
        check("winner_idx==1 (higher weight)", t_win_c == 1);

        // ==================================================================
        // TEST 6: Feedback neuron
        //   w_syn[0][D0_NI]=200 (index D0_NI = 4 is the feedback input).
        //   With no external input the NOR-feedback register goes high the
        //   cycle after no output spiked, driving neuron 0 to eventually fire.
        // ==================================================================
        $display("\n[%0t] TEST 6: feedback neuron drives spike", $time);
        for (int j = 0; j < D0_NO; j++)
            for (int i = 0; i < D0_NIT; i++) d0_wsyn[j][i] = 8'd0;
        d0_wsyn[0][D0_NI] = 8'd200;   // feedback input index = D0_NI
        d0_reset();
        t_spk_c = -1;
        for (int c = 0; c < 15; c++) begin
            d0_step('0);
            if (d0_spk[0] && t_spk_c < 0) t_spk_c = c;
        end
        check("feedback drove neuron 0 to spike", t_spk_c >= 0);

        // ==================================================================
        // TEST 7: STDP -- LTP on causal pre→post pair (reward_en=1)
        //   pre_spk[0]=1 continuously.  Spike 1: elig_trace=0 → w_next=w_syn.
        //   Spike 2: elig_trace=9 (LTP from first post_edge, one-cycle delay)
        //           → delta_w = 9>>>2 = 2 → w_next[0][0] = 82 > 80.
        // ==================================================================
        $display("\n[%0t] TEST 7: STDP -- LTP (causal pre->post, reward_en=1)", $time);
        for (int j = 0; j < DL_NO; j++)
            for (int i = 0; i < DL_NIT; i++) d1_wsyn[j][i] = 8'd0;
        d1_wsyn[0][0] = 8'd80;
        d1_ren = 1'b1;
        d1_reset();
        t_sc = 0; t_w_up = 1'b0;
        for (int c = 0; c < 20; c++) begin
            d1_step(2'b01);
            if (d1_spk[0]) begin
                t_sc++;
                if (t_sc >= 2 && int'(d1_wnxt[0][0]) > 80) t_w_up = 1'b1;
            end
        end
        check("STDP: >=2 spikes occurred",           t_sc >= 2);
        check("STDP: w_next > w_syn at 2nd spike",   t_w_up);
        d1_ren = 1'b0;
        d1_reset();

        // ==================================================================
        // TEST 8: STDP -- no weight change when reward_en=0
        //   delta_w=0 regardless of elig_trace when reward_en is low.
        // ==================================================================
        $display("\n[%0t] TEST 8: STDP -- w_next==w_syn when reward_en=0", $time);
        for (int j = 0; j < DL_NO; j++)
            for (int i = 0; i < DL_NIT; i++) d1_wsyn[j][i] = 8'd0;
        d1_wsyn[0][0] = 8'd80;
        d1_ren = 1'b0;
        d1_reset();
        t_w_chg = 1'b0;
        for (int c = 0; c < 20; c++) begin
            d1_step(2'b01);
            if (d1_wnxt[0][0] !== 8'd80) t_w_chg = 1'b1;
        end
        check("STDP: w_next unchanged when reward_en=0", !t_w_chg);
        d1_reset();

        // ==================================================================
        // TEST 9: R-STDP -- LTP with positive dopamine
        //   delta_w = (elig_trace * dopamine) >>> LR_SHIFT = (9*4)>>>2 = 9
        //   w_next[0][0] = 89 at second spike.
        // ==================================================================
        $display("\n[%0t] TEST 9: R-STDP -- LTP with positive dopamine (+4)", $time);
        for (int j = 0; j < DL_NO; j++)
            for (int i = 0; i < DL_NIT; i++) d2_wsyn[j][i] = 8'd0;
        d2_wsyn[0][0] = 8'd80;
        d2_ren = 1'b1;
        d2_dop = 4'sd4;
        d2_reset();
        t_sc = 0; t_w_up = 1'b0;
        for (int c = 0; c < 20; c++) begin
            d2_step(2'b01);
            if (d2_spk[0]) begin
                t_sc++;
                if (t_sc >= 2 && int'(d2_wnxt[0][0]) > 80) t_w_up = 1'b1;
            end
        end
        check("R-STDP: >=2 spikes occurred",               t_sc >= 2);
        check("R-STDP: w_next > w_syn (positive dopamine)", t_w_up);
        d2_ren = 1'b0;
        d2_reset();

        // ==================================================================
        // TEST 10: R-STDP -- LTD with negative dopamine
        //   delta_w = (9 * -4) >>> 2 = -9 → w_next[0][0] = 71 < 80.
        // ==================================================================
        $display("\n[%0t] TEST 10: R-STDP -- LTD with negative dopamine (-4)", $time);
        for (int j = 0; j < DL_NO; j++)
            for (int i = 0; i < DL_NIT; i++) d2_wsyn[j][i] = 8'd0;
        d2_wsyn[0][0] = 8'd80;
        d2_ren = 1'b1;
        d2_dop = -4'sd4;
        d2_reset();
        t_sc = 0; t_w_dn = 1'b0;
        for (int c = 0; c < 20; c++) begin
            d2_step(2'b01);
            if (d2_spk[0]) begin
                t_sc++;
                if (t_sc >= 2 && int'(d2_wnxt[0][0]) < 80) t_w_dn = 1'b1;
            end
        end
        check("R-STDP: >=2 spikes occurred",               t_sc >= 2);
        check("R-STDP: w_next < w_syn (negative dopamine)", t_w_dn);

        // ==================================================================
        // Summary
        // ==================================================================
        $display("\n[%0t] ===== Testbench complete: %0d passed, %0d failed =====",
                 $time, pass_count, fail_count);
        if (fail_count == 0) $display("[%0t] ALL TESTS PASSED", $time);
        else                  $display("[%0t] %0d TEST(S) FAILED", $time, fail_count);

        $finish;
    end

    // =========================================================================
    // Waveform dump
    // =========================================================================
    initial begin
        $dumpfile("tb_SNN_core.vcd");
        $dumpvars(0, tb_SNN_core);
    end

endmodule
