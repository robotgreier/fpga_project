module synapse_core #(
    parameter int LR_SHIFT     = 2,
    parameter int T_PRE        = 2,
    parameter int T_POST       = 2,
    parameter int TAU_E_SHIFT  = 2,
    parameter int DW_POS       = 16,
    parameter int DW_NEG       = 64,
    parameter int W_MIN        = 8,
    parameter int W_MAX        = 255,
    parameter int LEARNING_MODE = 0
  ) (
    input logic clk,
    input logic pre_spk,                // Pre-synaptic spike input
    input logic signed [3:0] dopamine,  // Dopamine signal for reward-based learning
    input logic reward_en,              // Reward enable signal
    input logic [7:0] w_syn,            // Synaptic weight
    input logic post_spk,              // Post-synaptic spike output
    output logic [7:0] w_next,           // Updated synaptic weight
    output logic [7:0] I_syn             // Synaptic current output
  );

  // Internal signals
  logic signed [8:0] elig_trace; // Eligibility trace (matches eligibility_updater output)
  logic signed [7:0] delta_w;    // Weight change from reward application
  logic signed [8:0] w_sum;      // Intermediate sum before clamping

  assign I_syn = (pre_spk) ? w_syn : 0; // Output synaptic current based on pre-synaptic spike

  // Instantiate eligibility updater
  eligibility_updater #(
    .T_PRE(T_PRE),
    .T_POST(T_POST),
    .TAU_E_SHIFT(TAU_E_SHIFT),
    .DW_POS(DW_POS),
    .DW_NEG(DW_NEG),
    .LEARNING_MODE(LEARNING_MODE),
    .MAX_E_TRACE(255),
    .MIN_E_TRACE(-256)
  ) elig_upd (
    .clk(clk),
    .pre_spk(pre_spk),
    .post_spk(post_spk),
    .elig_trace(elig_trace)
  );

  // Instantiate reward application module
  apply_reward #(
    .LR_SHIFT(LR_SHIFT),
    .LEARNING_MODE(LEARNING_MODE)
  ) reward_app (
    .clk(clk),
    .dopamine(dopamine),
    .elig_trace(elig_trace),
    .reward_en(reward_en),
    .delta_w(delta_w)
  );

  // Compute sum combinationally, then clamp and register
  assign w_sum = $signed({1'b0, w_syn}) + delta_w;

  always_ff @(posedge clk)
  begin
    if      (w_sum > signed'(W_MAX)) w_next <= W_MAX;
    else if (w_sum < signed'(W_MIN)) w_next <= W_MIN;
    else                             w_next <= w_sum[7:0];
  end

endmodule
