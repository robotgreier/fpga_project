module dopamine_loader (
    input logic clk, rst,
    input logic [7:0] data,
    input logic [7:0] adr,
    output logic signed [3:0] dopamine,
    output logic reward_en
  );

  localparam int DOP_ADR = 199;

  always_comb begin : get_dopamine
    if (adr == DOP_ADR)
      dopamine = data[3:0];
    else
      dopamine = '0;
  end

  always_comb begin : get_reward_en
    if (adr == DOP_ADR)
      reward_en = data != 0;
    else
      reward_en = 1'b0;
  end

endmodule
