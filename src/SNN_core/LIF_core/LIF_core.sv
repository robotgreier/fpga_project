module LIF_core #(
    parameter int DECAY     = 63,
    parameter int THRESHOLD = 1023,
    parameter int RESET     = 0
  ) (
    input  logic               clk,
    input  logic               run,            // Clock enable: only update on asserted cycles
    input  logic               inhibit,        // Lateral inhibition: suppress spike and reset mem
    input  logic [15:0] i_syn,          // Synaptic input current
    input  logic               rst,            // Reset
    output logic               spk,            // Spike output
    output logic [15:0] pre_reset_mem   // Membrane potential before any reset (used for WTA)
  );

  logic [15:0] mem;
  logic [15:0] mem_next;

  always_comb begin
    mem_next = (mem > DECAY) ? mem - DECAY + i_syn : i_syn;
  end

  always_ff @(posedge clk)
  begin
    if (rst) begin
      spk           <= '0;
      mem           <= 16'(RESET);
      pre_reset_mem <= 16'(RESET);
    end else if (run) begin
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