module SNN_core #(
    parameter int DECAY        = 256,
    parameter int THRESHOLD    = 1024,
    parameter int RESET        = 0,
    parameter int LR_SHIFT     = 2,
    parameter int T_PRE        = 2,
    parameter int T_POST       = 2,
    parameter int TAU_E_SHIFT  = 2,
    parameter int DW_POS       = 16,
    parameter int DW_NEG       = 64,
    parameter int W_MIN        = 8,
    parameter int W_MAX        = 255,
    parameter int LEARNING_MODE = 0,  // 0: None, 1: R-STDP, 2: STDP
    parameter int N_INPUTS     = 31,
    parameter int N_OUTPUTS    = 4
  ) (
    input  logic                           clk,
    input  logic [N_INPUTS-1:0]           pre_spk,   // Pre-synaptic input spikes
    input  logic signed [3:0]             dopamine,  // Reward signal (R-STDP only)
    input  logic                          reward_en, // Apply reward pulse (R-STDP only)
    output logic [N_OUTPUTS-1:0]          spk_out,   // Output spikes
    output logic [$clog2(N_OUTPUTS)-1:0]  winner_idx // WTA winner index
  );

  // ---------------------------------------------------------------------------
  // Weight storage: initialised to midpoint; written back after reward
  // ---------------------------------------------------------------------------
  logic [7:0] weights [N_OUTPUTS-1:0][N_INPUTS-1:0];

  initial begin
    for (int j = 0; j < N_OUTPUTS; j++)
      for (int ii = 0; ii < N_INPUTS; ii++)
        weights[j][ii] = 8'((W_MIN + W_MAX) / 2);
  end

  // ---------------------------------------------------------------------------
  // Internal wires
  // ---------------------------------------------------------------------------
  // Unpacked OK: only accessed with constant genvar indices in generate blocks
  logic [7:0] I_syn_mat  [N_OUTPUTS-1:0][N_INPUTS-1:0];
  logic [7:0] w_next_mat [N_OUTPUTS-1:0][N_INPUTS-1:0];

  // Packed: passed as ports or driven with variable indices in always_comb
  logic [N_OUTPUTS-1:0][15:0]         pre_reset_mem;
  logic [N_OUTPUTS-1:0][15:0]         i_sum;
  logic [N_OUTPUTS-1:0][N_INPUTS-1:0] pre_spk_gated;
  logic [N_OUTPUTS-1:0]               post_spk_gated;
  logic [N_OUTPUTS-1:0]               reward_en_syn;
  logic [N_OUTPUTS-1:0]               inhibit;

  // ---------------------------------------------------------------------------
  // WTA: combinational from registered spk_out and pre_reset_mem
  // ---------------------------------------------------------------------------
  WTA #(.N_OUTPUTS(N_OUTPUTS)) wta_inst (
    .spk(spk_out),
    .pre_reset_mem(pre_reset_mem),
    .winner_idx(winner_idx)
  );

  // ---------------------------------------------------------------------------
  // Spike gating (STDP: only winner row sees real spikes)
  // -------------------------------- -------------------------------------------
  always_comb begin
    for (int j = 0; j < N_OUTPUTS; j++) begin
      if (LEARNING_MODE == 2) begin
        pre_spk_gated[j]  = (winner_idx == j) ? pre_spk    : '0;
        post_spk_gated[j] = (winner_idx == j) ? spk_out[j] : 1'b0;
      end else begin
        pre_spk_gated[j]  = pre_spk;
        post_spk_gated[j] = spk_out[j];
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Per-row reward enable
  //   R-STDP (1): external reward_en, winner only
  //   STDP   (2): immediate on any spike, dopamine=1 implicit in apply_reward
  //   None   (0): never
  // ---------------------------------------------------------------------------
  always_comb begin
    for (int j = 0; j < N_OUTPUTS; j++) begin
      case (LEARNING_MODE)
        1:       reward_en_syn[j] = reward_en && (winner_idx == j);
        2:       reward_en_syn[j] = |spk_out;
        default: reward_en_syn[j] = 1'b0;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Lateral inhibition (STDP only): reset non-winner mem when spikes occur
  // ---------------------------------------------------------------------------
  always_comb begin
    for (int j = 0; j < N_OUTPUTS; j++)
      inhibit[j] = (LEARNING_MODE == 2) && (winner_idx != j) && (|spk_out);
  end

  // ---------------------------------------------------------------------------
  // Current accumulation: sum I_syn across all inputs per output neuron
  // ---------------------------------------------------------------------------
  always_comb begin
    for (int j = 0; j < N_OUTPUTS; j++) begin
      i_sum[j] = '0;
      for (int ii = 0; ii < N_INPUTS; ii++)
        i_sum[j] += 16'(I_syn_mat[j][ii]);
    end
  end

  // ---------------------------------------------------------------------------
  // Generate: N_OUTPUTS LIF neurons, each driven by N_INPUTS synapses
  // ---------------------------------------------------------------------------
  genvar j, i;
  generate
    for (j = 0; j < N_OUTPUTS; j++) begin : gen_neurons

      LIF_core #(
        .DECAY(DECAY),
        .THRESHOLD(THRESHOLD),
        .RESET(RESET)
      ) lif_inst (
        .clk(clk),
        .inhibit(inhibit[j]),
        .i_syn(i_sum[j]),
        .spk(spk_out[j]),
        .pre_reset_mem(pre_reset_mem[j])
      );

      for (i = 0; i < N_INPUTS; i++) begin : gen_synapses
        synapse_core #(
          .LR_SHIFT(LR_SHIFT),
          .T_PRE(T_PRE),
          .T_POST(T_POST),
          .TAU_E_SHIFT(TAU_E_SHIFT),
          .DW_POS(DW_POS),
          .DW_NEG(DW_NEG),
          .W_MIN(W_MIN),
          .W_MAX(W_MAX),
          .LEARNING_MODE(LEARNING_MODE)
        ) syn_inst (
          .clk(clk),
          .pre_spk(pre_spk_gated[j][i]),
          .post_spk(post_spk_gated[j]),
          .dopamine(dopamine),
          .reward_en(reward_en_syn[j]),
          .w_syn(weights[j][i]),
          .w_next(w_next_mat[j][i]),
          .I_syn(I_syn_mat[j][i])
        );
      end

    end
  endgenerate

  // ---------------------------------------------------------------------------
  // Weight writeback: write w_next into array when reward fires.
  // w_next is registered inside synapse_core (1-cycle pipeline latency).
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    for (int j = 0; j < N_OUTPUTS; j++)
      for (int ii = 0; ii < N_INPUTS; ii++)
        if (reward_en_syn[j])
          weights[j][ii] <= w_next_mat[j][ii];
  end

endmodule
