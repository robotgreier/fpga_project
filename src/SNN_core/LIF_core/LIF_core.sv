module LIF_core #(
    parameter int DECAY      = 63,
    parameter int THRESHOLD  = 1023,
    parameter int RESET      = 0,
    parameter int REFRACTORY = 0   // Dead-tick count after a spike (0 = disabled)
  ) (
    input  logic               clk,
    input  logic               run,            // Clock enable: only update on asserted cycles
    input  logic               inhibit,        // Lateral inhibition: suppress spike and reset mem
    input  logic [15:0] i_syn,          // Synaptic input current
    input  logic               rst,            // Reset
    output logic               spk,            // Spike output
    output logic [15:0] pre_reset_mem   // Membrane potential before any reset (used for WTA)
  );

  localparam int REFRAC_W = (REFRACTORY < 2) ? 1 : $clog2(REFRACTORY + 1);

  logic [15:0]         mem;
  logic [15:0]         mem_next;
  logic [REFRAC_W-1:0] refractory_timer;
  logic                in_refractory;

  assign in_refractory = (refractory_timer != '0);

  always_comb begin
    mem_next = (mem > DECAY) ? mem - DECAY + i_syn : i_syn;
  end

  always_ff @(posedge clk)
  begin
    if (rst) begin
      spk              <= '0;
      mem              <= 16'(RESET);
      pre_reset_mem    <= 16'(RESET);
      refractory_timer <= '0;
    end else if (run) begin
      if (in_refractory) begin
        // Refractory: hold at reset, suppress spike, discard synaptic input
        spk              <= 1'b0;
        mem              <= 16'(RESET);
        pre_reset_mem    <= 16'(RESET);
        refractory_timer <= refractory_timer - 1'b1;
      end else if (inhibit) begin
        pre_reset_mem <= mem_next;
        spk <= 1'b0;
        mem <= 16'(RESET);
      end else if (mem_next >= THRESHOLD) begin
        pre_reset_mem    <= mem_next;
        spk              <= 1'b1;
        mem              <= 16'(RESET);
        refractory_timer <= REFRAC_W'(REFRACTORY);
      end else begin
        pre_reset_mem <= mem_next;
        spk <= 1'b0;
        mem <= mem_next;
      end
    end
  end

endmodule
