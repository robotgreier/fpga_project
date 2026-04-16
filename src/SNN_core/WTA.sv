module WTA #(
    parameter int N_OUTPUTS = 3
) (
    input  logic [N_OUTPUTS-1:0]            spk,
    input  logic [N_OUTPUTS-1:0][15:0]      pre_reset_mem,
    output logic [$clog2(N_OUTPUTS)-1:0]    winner_idx,
    output logic                            winner_valid
);

  logic [15:0] max_mem;

  // A winner exists only when at least one neuron spiked
  assign winner_valid = |spk;

  always_comb begin
    winner_idx = '0;
    max_mem    = '0;
    for (int i = 0; i < N_OUTPUTS; i++) begin
      if (spk[i] && pre_reset_mem[i] >= max_mem) begin
        max_mem    = pre_reset_mem[i];
        winner_idx = i[$clog2(N_OUTPUTS)-1:0];
      end
    end
  end

endmodule
