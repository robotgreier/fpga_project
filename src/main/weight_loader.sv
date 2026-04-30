module weight_loader #(
    parameter int N_INPUTS      = 31,
    parameter int N_OUTPUTS     = 4,
    parameter int FEEDBACK      = 1,
    parameter int W_INIT        = 131,
    parameter bit RESET_WEIGHTS = 0   // 1: rst wipes w_temp to W_INIT, 0: w_temp survives rst
  ) (
    input logic clk, rst,
    input logic [7:0] data,
    input logic [7:0] adr,
    output logic [7:0] w_next  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0]
  );

  localparam int ADR_MIN = 0;
  localparam int ADR_MAX = N_OUTPUTS * (N_INPUTS + FEEDBACK) - 1;

  logic [7:0] w_temp  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0];

  initial foreach (w_temp[i,j]) w_temp[i][j] = W_INIT[7:0];

  always_ff @(posedge clk)
  begin : get_weight
    if (RESET_WEIGHTS && rst)
      foreach (w_temp[i,j]) w_temp[i][j] <= W_INIT[7:0];
    else if (adr >= ADR_MIN && adr <= ADR_MAX)
    begin
      // Decode adr into matrix indices
      automatic int j = adr / (N_INPUTS+FEEDBACK); automatic int ii = adr % (N_INPUTS+FEEDBACK);
      w_temp[j][ii] <= data;
    end
  end

  assign w_next = w_temp;

endmodule
