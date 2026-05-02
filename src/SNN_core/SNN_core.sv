module SNN_core #(
    parameter int  DECAY         = 63,
    parameter int  THRESHOLD     = 1023,
    parameter int  RESET         = 0,
    parameter int  LR_SHIFT      = 7,
    parameter int  T_PRE         = 2,
    parameter int  T_POST        = 2,
    parameter int  TAU_E_SHIFT   = 3,
    parameter int  DW_POS        = 32,
    parameter int  DW_NEG        = 16,
    parameter int  W_MIN         = 16,
    parameter int  W_MAX         = 254,
    parameter int  LEARNING_MODE = 1,  // 0: None, 1: R-STDP, 2: STDP
    parameter int  N_INPUTS      = 31,
    parameter int  N_OUTPUTS     = 4,
    parameter int  FEEDBACK      = 1   // 1: append NOR-feedback neuron as extra input
  ) (
    input  logic                                                    clk,
    input  logic                                                    run,            // Clock enable: execute one forward pass per pulse
    input  logic                                                    rst,
    input  logic [N_INPUTS-1:0]                                     spiketrain,
    input  logic signed [3:0]                                       dopamine,
    input  logic                                                    reward_en,
    input  logic [7:0] w_syn  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0],  // Weight matrix in
    output logic [N_OUTPUTS-1:0]                                    spk_out,
    output logic [$clog2(N_OUTPUTS)-1:0]                            winner_idx,
    output logic [7:0] w_next [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0]    // Updated weight matrix out
  );

  // ---------------------------------------------------------------------------
  // Feedback neuron: fires when no output spiked last cycle (NOR of spk_out)
  // ---------------------------------------------------------------------------
  localparam int N_IN_TOTAL = N_INPUTS + FEEDBACK;

  logic                  feedback_reg;
  logic [N_IN_TOTAL-1:0] spiketrain_fb;

  always_ff @(posedge clk)
    if (rst)      feedback_reg <= 1'b0;
    else if (run) feedback_reg <= FEEDBACK ? ~|spk_out : 1'b0;

  if (FEEDBACK) assign spiketrain_fb = {feedback_reg, spiketrain};
  else          assign spiketrain_fb = spiketrain;

  // ---------------------------------------------------------------------------
  // Internal wires
  // ---------------------------------------------------------------------------
  logic [7:0] I_syn_mat [N_OUTPUTS-1:0][N_IN_TOTAL-1:0];

  logic [N_OUTPUTS-1:0]                 spk_raw;       // raw LIF spikes
  logic signed [N_OUTPUTS-1:0][15:0]    pre_reset_mem;
  logic signed [N_OUTPUTS-1:0][15:0]    i_sum;
  logic [N_OUTPUTS-1:0][N_IN_TOTAL-1:0] pre_spk_gated;
  logic [N_OUTPUTS-1:0]                 post_spk_gated;
  logic [N_OUTPUTS-1:0]                 reward_en_syn;
  logic [N_OUTPUTS-1:0]                 inhibit;

  // ---------------------------------------------------------------------------
  // WTA: picks winner from raw LIF spikes
  // ---------------------------------------------------------------------------
  logic                         wta_valid_c;
  logic [$clog2(N_OUTPUTS)-1:0] wta_idx_c;
  logic                         winner_valid;

  WTA #(.N_OUTPUTS(N_OUTPUTS)) wta_inst (
    .spk          (spk_raw),
    .pre_reset_mem(pre_reset_mem),
    .winner_idx   (wta_idx_c),
    .winner_valid (wta_valid_c)
  );

  // Pipeline register: breaks spk_reg → WTA → e_trace2_carry path (~19 levels, -2.7 ns)
  always_ff @(posedge clk) begin
    if (rst) begin
      winner_idx   <= '0;
      winner_valid <= 1'b0;
    end else begin
      winner_idx   <= wta_idx_c;
      winner_valid <= wta_valid_c;
    end
  end

  // Build one-hot spk_out from registered winner
  always_comb begin
    spk_out = '0;
    if (winner_valid)
      spk_out[winner_idx] = 1'b1;
  end

  // ---------------------------------------------------------------------------
  // Spike gating, reward enable, lateral inhibition
  // ---------------------------------------------------------------------------
  always_comb
    for (int j = 0; j < N_OUTPUTS; j++) begin
      // STDP: only suppress losers when a spike is actually occurring;
      // before the first spike, every neuron must see input or none can fire.
      pre_spk_gated[j]  = (LEARNING_MODE == 2 && winner_valid && winner_idx != j) ? '0   : spiketrain_fb;
      post_spk_gated[j] = (LEARNING_MODE == 2 && winner_valid && winner_idx != j) ? 1'b0 : spk_out[j];
      inhibit[j]        = (LEARNING_MODE == 2) & (winner_idx != j) & |spk_out;

      unique case (LEARNING_MODE)
        1:       reward_en_syn[j] = reward_en & (winner_idx == j);
        2:       reward_en_syn[j] = reward_en & |spk_out;
        default: reward_en_syn[j] = 1'b0;
      endcase
    end

  // ---------------------------------------------------------------------------
  // Current accumulation: sum of synaptic currents for each neuron
  // ---------------------------------------------------------------------------
  always_comb
    for (int j = 0; j < N_OUTPUTS; j++) begin
      i_sum[j] = '0;
      for (int ii = 0; ii < N_IN_TOTAL; ii++)
        i_sum[j] += 16'(I_syn_mat[j][ii]);
    end

  // ---------------------------------------------------------------------------
  // Generate: N_OUTPUTS LIF neurons × N_IN_TOTAL synapses each
  // ---------------------------------------------------------------------------
  for (genvar j = 0; j < N_OUTPUTS; j++) begin : gen_neurons

    LIF_core #(
      .DECAY(DECAY),
      .THRESHOLD(THRESHOLD),
      .RESET(RESET)
    ) lif_inst (
      .clk(clk),
      .run(run),
      .rst(rst),
      .inhibit(inhibit[j]),
      .i_syn(i_sum[j]),
      .spk(spk_raw[j]),
      .pre_reset_mem(pre_reset_mem[j])
    );

    for (genvar i = 0; i < N_IN_TOTAL; i++) begin : gen_synapses
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
        .run(run),
        .rst(rst),
        .pre_spk(pre_spk_gated[j][i]),
        .post_spk(post_spk_gated[j]),
        .dopamine(dopamine),
        .reward_en(reward_en_syn[j]),
        .w_syn(w_syn[j][i]),
        .w_next(w_next[j][i]),
        .I_syn(I_syn_mat[j][i])
      );
    end

  end

endmodule
