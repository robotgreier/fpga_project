module weight_loader #(
    parameter int N_INPUTS     = 31,
    parameter int N_OUTPUTS    = 4,
    parameter int FEEDBACK     = 1,
  ) (
    input logic clk, rst,
    input logic data,
    input logic adr,
    output logic [7:0] w_next  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0]          
  );



endmodule