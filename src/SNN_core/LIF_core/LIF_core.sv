module LIF_core #(
    parameter int DECAY     = 256,
    parameter int THRESHOLD = 1024,
    parameter int RESET     = 0
  ) (
    input  logic        clk,
    input  logic        inhibit,        // Lateral inhibition: suppress spike and reset mem
    input  logic [15:0] i_syn,          // Synaptic input current
    output logic        spk,            // Spike output
    output logic [15:0] pre_reset_mem   // Membrane potential before any reset (used for WTA)
  );

  logic [15:0] mem;
  logic [15:0] mem_next;

  always_ff @(posedge clk)
  begin
    mem_next = (mem > DECAY) ? mem - DECAY + i_syn : i_syn;
    pre_reset_mem <= mem_next; // always capture natural value before any override

    if (inhibit) begin
      spk <= 0;
      mem <= RESET;
    end else if (mem_next >= THRESHOLD) begin
      spk <= 1;
      mem <= RESET;
    end else begin
      spk <= 0;
      mem <= mem_next;
    end
  end

endmodule
