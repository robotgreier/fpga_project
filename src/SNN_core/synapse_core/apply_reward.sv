module apply_reward #(
    parameter int LR_SHIFT = 2,
    parameter int LEARNING_MODE = 2
  ) (
    input  logic signed [3:0] dopamine,
    input  logic signed [8:0] elig_trace,
    input  logic              reward_en,
    output logic signed [8:0] delta_w
  );

  if (LEARNING_MODE == 1) begin : g_rstdp
    logic signed [12:0] product;
    always_comb begin
      product = '0;
      delta_w = '0;
      if (reward_en) begin
        product = (elig_trace * dopamine) >>> LR_SHIFT;
        if      (product > 255)  delta_w =  255;
        else if (product < -255) delta_w = -255;
        else                     delta_w = product[8:0];
      end
    end
  end else if (LEARNING_MODE == 2) begin : g_stdp
    logic signed [12:0] product;
    always_comb begin
      product = elig_trace >>> LR_SHIFT;
      delta_w = product[8:0];
    end
  end else begin : g_off
    assign delta_w = '0;
  end

endmodule
