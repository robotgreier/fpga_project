module dopamine_loader #(
    parameter int DOP_ADR = 199
  ) (
    input logic clk, rst,
    input logic [7:0] data,
    input logic [7:0] adr,
    output logic signed [3:0] dopamine
  );

  always_comb begin : get_dopamine
    if (adr == DOP_ADR)
      dopamine = data[3:0];
    else
      dopamine = '0;
  end

endmodule
