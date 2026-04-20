module main #(
  // SNN parameters
    parameter int DECAY        = 256,
    parameter int THRESHOLD    = 1024,
    parameter int RESET        = 0,
    parameter int LR_SHIFT     = 2,
    parameter int T_PRE        = 2,
    parameter int T_POST       = 2,
    parameter int TAU_E_SHIFT  = 2,
    parameter int DW_POS       = 16,
    parameter int DW_NEG       = 64,
    parameter int W_MIN        = 8,
    parameter int W_MAX        = 255,
    parameter int LEARNING_MODE = 0,  // 0: None, 1: R-STDP, 2: STDP
    parameter int N_INPUTS     = 31,
    parameter int N_OUTPUTS    = 3,
    // Main parameters
    parameter int MAX_DATA     = 16
  )(
  input logic clk, rx, reset,
  output wire tx
);

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
  .BIT_WIDTH(8),
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
  .BIT_WIDTH(8)
) uart_r (
  .clk(clk),
  .rx(rx), // RX line
  .ready(rx_ready), // Is high when data transaction is complete
  .success(rx_success), // Is high if transaction is considered successfull (when stop bit is high)
  .data(rx_data) // Data received
);

uart_tx #(
  .CLOCK_BAUD_RATIO(400),
  .BIT_WIDTH(8)
) uart_t (
  .clk(clk),
  .tx(tx), // TX line
  .transmit(master_transmit), // Trigger to send data
  .ready(tx_ready), // Is high when uart is available to transmit
  .data(master_data) // Data to be sent
);

fletcher #(
    .BIT_WIDTH(8)
) fletch (
    .reset(verifier_fletcher_reset),
    .check(verifier_check),
    .data(rx_data),
    .sum(fletcher_sum)
);

fifo_memory #(
    .ADDRESS_COUNT(MAX_DATA),
    .BIT_WIDTH(8)
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
    .BIT_WIDTH(8),
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

endmodule