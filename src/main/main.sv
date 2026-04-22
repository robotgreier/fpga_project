module main #(
  // SNN parameters
    parameter int DECAY         = 256,
    parameter int THRESHOLD     = 1024,
    parameter int RESET         = 0,
    parameter int LR_SHIFT      = 2,
    parameter int T_PRE         = 2,
    parameter int T_POST        = 2,
    parameter int TAU_E_SHIFT   = 2,
    parameter int DW_POS        = 16,
    parameter int DW_NEG        = 64,
    parameter int W_MIN         = 8,
    parameter int W_MAX         = 254,
    parameter logic [7:0] W_INIT = (W_MIN + W_MAX) / 2,
    parameter int LEARNING_MODE = 0,  // 0: None, 1: R-STDP, 2: STDP
    parameter int N_INPUTS      = 31,
    parameter int N_OUTPUTS     = 4,
    parameter int FEEDBACK      = 1,   // 1: append NOR-feedback neuron as extra input
    // Main parameters
    parameter int MAX_DATA      = 16,
    parameter int BIT_WIDTH     = 8
  )(
  input logic CLK100MHZ, uart_txd_in,
  output wire uart_rxd_out
);

// Connections
wire clk, rx, tx;
reg reset;
assign clk = CLK100MHZ;
assign rx = uart_txd_in;
assign tx = uart_rxd_out;

// Reset logic
reg reset_counter = 0;
reg already_reset = 0;

always @(posedge clk) begin
  if (already_reset == 1'b0) begin  // Check if system is already delayed
    if (reset_counter >= 60) begin // Check if counter is over 60 cycles
      if (reset == 1'b1) begin // Check if reset signal is high
        reset <= 1'b0;
        already_reset <= 1'b1;
      end
      else begin
        reset <= 1'b1;
      end
    end
    else begin
      reset_counter <= reset_counter + 1'b1;
    end
  end
end

// ----------------------- Verification things ------------------------------ //
wire  master_read, master_transmit; // Master signals
wire  [7:0] master_data;

wire  verifier_ready, // Verifier signals
      verifier_success,
      verifier_write,
      verifier_commit,
      verifier_fifo_reset,
      verifier_fletcher_reset,
      verifier_check;

wire  fifo_full, fifo_empty; // Fifo signals
wire  [7:0] fifo_data;


wire  fletcher_reset; // Fletcher signals
wire  [15:0] fletcher_sum;

wire  rx_ready, rx_success; // RX signals
wire  [7:0] rx_data;

wire  tx_ready; // TX signals

master #(
  .BIT_WIDTH(BIT_WIDTH),
  .LEN_MAX(MAX_DATA)
) mas (
  .clk(clk),
  .ready(verifier_ready),
  .success(verifier_success),
  .tx_ready(tx_ready),
  .reset(reset),
  .data_in(fifo_data),
  .read(master_read),
  .transmit(master_transmit),
  .data_out(master_data)
);

uart_rx #(
  .CLOCK_BAUD_RATIO(400),
  .BIT_WIDTH(BIT_WIDTH)
) uart_r (
  .clk(clk),
  .rx(rx), // RX line
  .ready(rx_ready), // Is high when data transaction is complete
  .success(rx_success), // Is high if transaction is considered successfull (when stop bit is high)
  .data(rx_data) // Data received
);

uart_tx #(
  .CLOCK_BAUD_RATIO(400),
  .BIT_WIDTH(BIT_WIDTH)
) uart_t (
  .clk(clk),
  .tx(tx), // TX line
  .transmit(master_transmit), // Trigger to send data
  .ready(tx_ready), // Is high when uart is available to transmit
  .data(master_data) // Data to be sent
);

fletcher #(
    .BIT_WIDTH(BIT_WIDTH)
) fletch (
    .reset(verifier_fletcher_reset),
    .check(verifier_check),
    .data(rx_data),
    .sum(fletcher_sum)
);

fifo_memory #(
    .ADDRESS_COUNT(MAX_DATA),
    .BIT_WIDTH(BIT_WIDTH)
) fifo (
    .clk(clk),
    .soft_reset(verifier_fifo_reset),
    .hard_reset(reset),
    .write(verifier_write),
    .commit(verifier_commit),
    .read(master_read),
    .full(fifo_full),
    .empty(fifo_empty),
    .data_in(rx_data),
    .data_out(fifo_data)
);

verifier #(
    .BIT_WIDTH(BIT_WIDTH),
    .LEN_MAX(MAX_DATA)
) veri (
    .clk(clk),
    .rx_ready(rx_ready),
    .rx_success(rx_success),
    .reset(reset),
    .fifo_full(fifo_full),
    .rx_data(rx_data),
    .fletcher_sum(fletcher_sum),
    .ready(verifier_ready),
    .success(verifier_success),
    .write(verifier_write),
    .commit(verifier_commit),
    .check(verifier_check),
    .fifo_reset(verifier_fifo_reset),
    .fletcher_reset(verifier_fletcher_reset)
    );


// ----------------------- SNN things ------------------------------ //

// Instantiate weight matrices
logic [7:0] w_syn  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0];
logic [7:0] w_next [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0];

// Initializing the weight matrix to default values at reset, otherwise w_next
always_ff @(posedge clk) begin
  if (reset)
    foreach (w_syn[i,j]) w_syn[i][j] <= W_INIT;
  else
    w_syn <= w_next;
end

// Load weights
// Temp signals
logic [7:0] master_address;
logic w_en, d_en;

weight_loader #(
    .N_INPUTS(N_INPUTS),
    .N_OUTPUTS(N_OUTPUTS),
    .FEEDBACK(FEEDBACK),
    .W_INIT(W_INIT)
) w_loader (
    .clk(clk),
    .rst(reset),
    .w_en(w_en),
    .data(fifo_data),
    .adr(master_address),  
    .w_next(w_next)
);


// Dump weights

logic [((N_INPUTS+FEEDBACK)*N_OUTPUTS*8)-1:0] w_parallel_out;
weight_dumper #(
    .N_INPUTS(N_INPUTS),
    .N_OUTPUTS(N_OUTPUTS),
    .FEEDBACK(FEEDBACK)
) w_dumper (
    .clk(clk),
    .rst(reset),
    .en(d_en),
    .adr(master_address),
    .w_syn(w_syn),
    .data_out(w_parallel_out)
);


// Load spikes
// Temp signals
logic done, s_en;
logic [(N_INPUTS) - 1:0] spiketrain; 

spike_loader #(
    .N_INPUTS(N_INPUTS)
) s_loader (
    .clk(clk),
    .rst(reset),
    .en(s_en),
    .data(fifo_data),
    .adr(master_address),  
    .done(done),
    .spiketrain(spiketrain)
);


// Instantiate SNN core
logic [N_OUTPUTS-1:0] spk_out;
logic [$clog2(N_OUTPUTS)-1:0] winner_idx;

// Temp signals
logic signed [7:0] dopamine;
logic reward_en;

SNN_core #(
    .DECAY(DECAY),
    .THRESHOLD(THRESHOLD),
    .RESET(RESET),
    .LR_SHIFT(LR_SHIFT),
    .T_PRE(T_PRE),
    .T_POST(T_POST),
    .TAU_E_SHIFT(TAU_E_SHIFT),
    .DW_POS(DW_POS),
    .DW_NEG(DW_NEG),
    .W_MIN(W_MIN),
    .W_MAX(W_MAX),
    .LEARNING_MODE(LEARNING_MODE),
    .N_INPUTS(N_INPUTS),
    .N_OUTPUTS(N_OUTPUTS),
    .FEEDBACK(FEEDBACK)
) snn (
    .clk(clk), 
    .rst(reset),
    .spiketrain(spiketrain),
    .dopamine(dopamine),
    .reward_en(reward_en),
    .w_syn(w_syn),
    .spk_out(spk_out),
    .winner_idx(winner_idx),
    .w_next(w_next)
);







endmodule