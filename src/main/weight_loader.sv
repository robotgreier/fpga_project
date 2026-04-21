module weight_loader #(
    parameter int N_INPUTS     = 31,
    parameter int N_OUTPUTS    = 4,
    parameter int FEEDBACK     = 1,
  ) (
    input logic clk, rst, w_en,
    input logic [7:0] data,
    input logic [15:0] adr,
    output logic [7:0] w_next  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0]
  );

  logic [7:0] w_temp  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0];

  always_ff @(posedge clk)
  begin : get_weight
    if (w_en)
    begin
      // Decode adr into matrix indices
    [j][ii] : j = adr / (N_INPUTS+FEEDBACK), ii = adr % (N_INPUTS+FEEDBACK);
      w_temp[j][ii] <= data;
    end
  end

  assign w_next = w_temp;

endmodule
