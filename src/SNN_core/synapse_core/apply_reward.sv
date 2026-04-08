module apply_reward #(
    parameter int LR_SHIFT = 2,      // Learning rate shift
    parameter int LEARNING_MODE = 2  // 0: None, 1: R-STDP, 2: STDP
  ) (
    input  logic signed [3:0] dopamine,   // Dopamine signal, 4-bit signed
    input  logic signed [8:0] elig_trace, // Eligibility trace, 9-bit signed to allow for negative values
    input  logic              reward_en,  // Enable signal for applying reward
    output logic signed [7:0] delta_w     // Weight change, 8-bit signed to allow for negative updates
  );

  logic signed [12:0] product; // Full-width intermediate result (9+4 = 13 bits)

  always_ff @(posedge reward_en)
  begin
    // Only apply reward if learning mode is R-STDP or STDP
    if (LEARNING_MODE == 0)
      delta_w <= '0; // No learning
    else if (LEARNING_MODE == 1)
    begin
      product = (elig_trace * dopamine) >>> LR_SHIFT; // Multiply eligibility and dopamine input and scale by learning rate
      delta_w <= product[7:0];
    end
    else if (LEARNING_MODE == 2) begin
      product = elig_trace >>> LR_SHIFT; // Scale eligibility trace by learning rate
      delta_w <= product[7:0];
    end
  end

endmodule
