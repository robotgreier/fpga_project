`timescale 1ns/1ps

module tb_functional_comparison;

  localparam int N_INPUTS      = 27;
  localparam int N_OUTPUTS     = 4;
  
  // Specific requested parameters
  localparam int DECAY         = 600;
  localparam int THRESHOLD     = 1000;
  localparam int RESET         = 0;
  localparam int REFRACTORY    = 1;

  localparam int LR_SHIFT      = 5;
  localparam int T_PRE         = 3;
  localparam int T_POST        = 1;
  localparam int TAU_E_SHIFT   = 2;
  localparam int DW_POS        = 10;
  localparam int DW_NEG        = 8;
  localparam int W_MIN         = 16;
  localparam int W_MAX         = 254;

  logic clk, rst, run;
  logic [N_INPUTS-1:0] spiketrain;
  logic [7:0] w_syn_load [N_OUTPUTS-1:0][N_INPUTS-1:0];
  logic [N_OUTPUTS-1:0] spk_out;
  logic [15:0] pre_reset_mem [N_OUTPUTS-1:0];

  // DUT Instance
  SNN_core #(
    .DECAY(DECAY), .THRESHOLD(THRESHOLD), .RESET(RESET), .REFRACTORY(REFRACTORY),
    .LR_SHIFT(LR_SHIFT), .T_PRE(T_PRE), .T_POST(T_POST), .TAU_E_SHIFT(TAU_E_SHIFT),
    .DW_POS(DW_POS), .DW_NEG(DW_NEG), .N_INPUTS(N_INPUTS), .N_OUTPUTS(N_OUTPUTS), .FEEDBACK(0)
  ) dut (
    .clk(clk), .run(run), .rst(rst), .spiketrain(spiketrain),
    .dopamine(4'sd0), .reward_en(1'b0), .w_syn(w_syn_load),
    .spk_out(spk_out)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  logic [N_INPUTS-1:0] stimulus [0:99];

always_comb begin
    for (int i = 0; i < N_OUTPUTS; i++) begin
       pre_reset_mem[i] = dut.pre_reset_mem[i];
    end
  end

  initial begin
    // Load generated files
    $readmemh("input_stimulus.mem", stimulus);
    $readmemh("weights_init.mem", w_syn_load);

    rst = 1; run = 0; #20; rst = 0; #10;

    $display("t | Stim Hex | Spikes | Mem0 | Mem1 | Mem2 | Mem3");
    for (int t = 0; t < 100; t++) begin
        @(negedge clk);
        spiketrain = stimulus[t];
        run = 1;
      @(posedge clk);
      #2; // Stable observation
      $display("%0d | %7H | %b | %d | %d | %d | %d", 
               t, spiketrain, spk_out,
               pre_reset_mem[0], pre_reset_mem[1], 
               pre_reset_mem[2], pre_reset_mem[3]);
      @(negedge clk);
      run = 0;
    end
    $finish;
  end
endmodule