module LIF_core #(
    parameter int signed DECAY     = 256,
    parameter int signed THRESHOLD = 1024,
    parameter int signed RESET     = 0
  ) (
    input  logic               clk,
    input  logic               inhibit,        // Lateral inhibition: suppress spike and reset mem
    input  logic signed [15:0] i_syn,          // Synaptic input current
    input  logic               rst,            // Reset
    output logic               spk,            // Spike output
    output logic signed [15:0] pre_reset_mem   // Membrane potential before any reset (used for WTA)
  );

  logic signed [15:0] mem;
  logic signed [15:0] mem_next;

  always_comb begin
    mem_next = (mem > DECAY) ? mem - DECAY + i_syn : i_syn;
  end

  always_ff @(posedge clk)
  begin
    if (rst) begin
      spk           <= '0;
      mem           <= 16'(RESET);
      pre_reset_mem <= 16'(RESET);
    end else begin
      pre_reset_mem <= mem_next;

      if (inhibit) begin
        spk <= '0;
        mem <= 16'(RESET);
      end else if (mem_next >= THRESHOLD) begin
        spk <= '1;
        mem <= 16'(RESET);
      end else begin
        spk <= '0;
        mem <= mem_next;
      end
    end
  end

endmodule