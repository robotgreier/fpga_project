module synapse_core #(
    parameter LR_SHIFT = 2,
    parameter W_INIT = NULL,
    parameter T_PRE = 2,
    parameter T_POST = 2,
    parameter TAU_E_SHIFT = 2,
    parameter  W_MIN = 8,
    parameter W_MAX = 255,
    parameter LEARNING_MODE = 0         // 0: No learning, 1: RSTDP, 2: STDP
  ) (
    input logic clk,
    input logic pre_spk,                // Pre-synaptic spike input
    input logic signed [3:0] dopamine,  // Dopamine signal for reward-based learning
    input logic reward_en,              // Reward enable signal
    input logic [7:0] w_syn,            // Synaptic weight
    output logic post_spk              // Post-synaptic spike output
  );

  // Internal registers
  logic [9:0] elig_trace;             // Eligibility trace for synaptic plasticity
  logic [3:0] pre_timer, post_timer;  // Timers for pre and post-synaptic spikes




endmodule
