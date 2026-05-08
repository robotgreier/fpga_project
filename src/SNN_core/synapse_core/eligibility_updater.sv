module eligibility_updater #(
    parameter int T_PRE         = 2,
    parameter int T_POST        = 2,
    parameter int TAU_E_SHIFT   = 3,
    parameter int DW_POS        = 32,
    parameter int DW_NEG        = 16,
    parameter int LEARNING_MODE = 1,   // 0: None, 1: R-STDP, 2: STDP
    parameter int MAX_E_TRACE   = 255,
    parameter int MIN_E_TRACE   = -256
  ) (
    input  logic              clk,
    input  logic              run,
    input  logic              pre_spk,
    input  logic              post_spk,
    input  logic              rst,
    output logic signed [8:0] elig_trace
  );

  if (LEARNING_MODE == 0) begin : g_off
    assign elig_trace = '0;
  end else begin : g_on
    localparam int DISABLED = -1;

    logic signed [4:0]  pre_timer,     post_timer;     // registered, signed to hold DISABLED (-1)
    logic signed [4:0]  pre_timer_adv, post_timer_adv; // after advance + expire (matches Python order)
    logic signed [4:0]  pre_timer_post_pre;            // pre_timer after pre-spike sets it to 0
    logic signed [4:0]  pre_timer_next, post_timer_next;
    logic signed [8:0]  e_trace;
    logic signed [10:0] e_next;
    logic signed [10:0] e_comb;
    logic signed [10:0] decay_amt;

    // Advance + expire — runs before consuming spikes (mirrors Python order)
    always_comb begin
      if (pre_timer >= 0) begin
        if (pre_timer + 1 > T_PRE) pre_timer_adv = DISABLED;
        else                       pre_timer_adv = pre_timer + 1;
      end else begin
        pre_timer_adv = DISABLED;
      end

      if (post_timer >= 0) begin
        if (post_timer + 1 > T_POST) post_timer_adv = DISABLED;
        else                         post_timer_adv = post_timer + 1;
      end else begin
        post_timer_adv = DISABLED;
      end
    end

    // Pre-spike zeros pre_timer; LTP gate uses this updated value so
    // simultaneous pre+post counts as LTP (matches Python).
    assign pre_timer_post_pre = pre_spk ? 5'sd0 : pre_timer_adv;

    assign pre_timer_next  = pre_timer_post_pre;
    assign post_timer_next = post_spk ? 5'sd0 : post_timer_adv;

    always_comb begin : e_next_calc
      e_comb = e_trace;
      // LTD: pre fires while post_timer (advanced) is active
      if (pre_spk  && post_timer_adv     >= 0)
        e_comb = e_comb - DW_NEG;
      // LTP: post fires while pre_timer (after pre-spike update) is active
      if (post_spk && pre_timer_post_pre >= 0)
        e_comb = e_comb + DW_POS;

      // Decay after STDP updates. Positive [1, 2^TAU_E_SHIFT-1] would shift
      // to 0 and stall — force decay=1 in that dead-zone so trace converges.
      decay_amt = e_comb >>> TAU_E_SHIFT;
      if (e_comb > 0 && decay_amt == 0)
        decay_amt = 11'sd1;
      e_comb = e_comb - decay_amt;

      e_next = e_comb;
    end

    always_ff @(posedge clk) begin : timer_block
      if (rst) begin
        pre_timer  <= DISABLED;
        post_timer <= DISABLED;
      end else if (run) begin
        pre_timer  <= pre_timer_next;
        post_timer <= post_timer_next;
      end
    end

    always_ff @(posedge clk) begin : eligibility_update
      if (rst) begin
        e_trace <= '0;
      end else if (run) begin
        if      (e_next > MAX_E_TRACE) e_trace <= MAX_E_TRACE;
        else if (e_next < MIN_E_TRACE) e_trace <= MIN_E_TRACE;
        else                           e_trace <= e_next[8:0];
      end
    end

    assign elig_trace = e_trace;
  end

endmodule
