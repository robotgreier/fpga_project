module weight_dumper #(
    parameter int N_INPUTS     = 31,
    parameter int N_OUTPUTS    = 4,
    parameter int FEEDBACK     = 1
  ) (
    input logic clk, rst, en,
    input logic [7:0] adr,
    input logic [7:0] w_syn  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0],
    output logic [((N_INPUTS+FEEDBACK)*N_OUTPUTS*8)-1:0] w_parallel_out
  );

    always_comb begin : parallelizer
        for (int i = 0; i < N_OUTPUTS; i++) begin
            for (int j = 0; j < (N_INPUTS + FEEDBACK); j++) begin
                w_parallel_out[(i*(N_INPUTS + FEEDBACK) + j)*8 +: 8] = w_syn[i][j];
            end
        end
    end

endmodule
