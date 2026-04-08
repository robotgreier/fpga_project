module LIF_core #(
    parameter int DECAY     = 256,
    parameter int THRESHOLD = 1024,
    parameter int RESET     = 0
  )(
    input  logic        clk,            // Enable signal for the neuron
    input  logic [15:0] i_syn,          // Synaptic input current, 8-bit wide
    output logic        spk,            // Output spike signal, goes high when the neuron fires
    output logic [15:0] pre_reset_mem   // Membrane potential before reset
  );

  // Internal membrane potential register
  logic [15:0] mem;
  logic [15:0] mem_next;

  always_ff @(posedge clk)
  begin
    // Leak and integrate: subtract decay, add synaptic input, clamp to 0 if negative
    // mem <= (mem > DECAY) ? mem - DECAY + i_syn : i_syn;  // Membrane potential clamped to 0
    mem_next = mem - DECAY + i_syn;

    if (mem_next >= THRESHOLD)
    begin
      spk           <= 1;         // Fire spike
      pre_reset_mem <= mem_next;  // Capture membrane potential before reset (used for WTA tie-breaking)
      mem           <= RESET;     // Reset membrane potential
    end
    else
    begin
      spk <= 0;                   // No spike
      mem <= mem_next;
    end
  end

endmodule
