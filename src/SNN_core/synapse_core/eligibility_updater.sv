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

    // Edge detection
    logic pre_spk_r, post_spk_r;
    logic pre_edge, post_edge;
    assign pre_edge  = pre_spk  & ~pre_spk_r;
    assign post_edge = post_spk & ~post_spk_r;
    logic signed [4:0]  pre_timer, post_timer; // signed to hold DISABLED (-1)
    logic signed [8:0]  e_trace;
    logic signed [10:0] e_next;
    logic signed [10:0] e_comb;

    always_ff @(posedge clk)
    begin
      if (rst) begin
        pre_spk_r  <= 1'b0;
        post_spk_r <= 1'b0;
      end else if (run) begin
        pre_spk_r  <= pre_spk;
        post_spk_r <= post_spk;
      end
    end

    // Timer logic (merged)
    always_ff @(posedge clk)
    begin : timer_block
      if (rst) begin
        pre_timer  <= DISABLED;
        post_timer <= DISABLED;
      end else if (run) begin
        // Pre timer
        if      (pre_edge)
          pre_timer  <= 0;
        else if (pre_timer  > T_PRE)
          pre_timer  <= DISABLED;
        else if (pre_timer  >= 0)
          pre_timer  <= pre_timer  + 1;

        // Post timer
        if      (post_edge)
          post_timer <= 0;
        else if (post_timer > T_POST)
          post_timer <= DISABLED;
        else if (post_timer >= 0)
          post_timer <= post_timer + 1;
      end
    end

    // Compute next eligibility trace combinationally
    always_comb
    begin : e_next_calc
      e_comb = e_trace;
      if (pre_edge  && post_timer >= 0)
        e_comb = e_comb - DW_NEG; // LTD
      if (post_edge && pre_timer  >= 0)
        e_comb = e_comb + DW_POS; // LTP
      e_comb = e_comb - (e_comb >>> TAU_E_SHIFT); // Decay after STDP updates

      e_next = e_comb;
    end

    // Clamp and register
    always_ff @(posedge clk)
    begin : eligibility_update
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
