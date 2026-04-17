module main (
  input logic clk, rx, reset,
  output wire tx
);

parameter MAX_DATA = 16;

wire  master_read, master_transmit; // Master signals
wire  [7:0] master_data;

wire  verifier_ready, // Verifier in signals
      verifier_success,
      verifier_write,
      verifier_commit,
      verifier_soft_reset,
      verifier_hard_reset,
      verifier_check;

wire  fifo_full, fifo_empty; // Fifo in signals
wire  [7:0] fifo_data;

wire  [15:0] fletcher_sum; // Fletcher in signals

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
    .reset(verifier_soft_reset),
    .check(verifier_check),
    .data(rx_data),
    .sum(fletcher_sum)
);

fifo_memory #(
    .ADDRESS_COUNT(MAX_DATA),
    .BIT_WIDTH(8)
) fifo (
    .clk(clk),
    .soft_reset(verifier_soft_reset),
    .hard_reset(verifier_hard_reset),
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
    .soft_reset(verifier_soft_reset),
    .hard_reset(verifier_hard_reset)
    );

endmodule