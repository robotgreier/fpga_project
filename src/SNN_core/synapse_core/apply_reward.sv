module apply_reward #(
    parameter int LR_SHIFT = 2,
    parameter int LEARNING_MODE = 2
  ) (
    input  logic              clk,        // unused, kept for port compatibility
    input  logic              rst,        // unused, kept for port compatibility
    input  logic signed [3:0] dopamine,
    input  logic signed [8:0] elig_trace,
    input  logic              reward_en,
    output logic signed [7:0] delta_w
  );

  logic signed [12:0] product;

  always_comb begin
    delta_w = '0;
    if (reward_en) begin
      if (LEARNING_MODE == 1) begin
        product = (elig_trace * dopamine) >>> LR_SHIFT;
        delta_w = product[7:0];
      end else if (LEARNING_MODE == 2) begin
        product = elig_trace >>> LR_SHIFT;
        delta_w = product[7:0];
      end
      // LEARNING_MODE == 0: delta_w stays 0
    end
  end

endmodule