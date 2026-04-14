module main (
  input wire clk
);

wire rx, tx, rx_ready, tx_ready, rx_success, tx_success, reset, write, read, full, empty, check_in, check_out;
wire [7:0] rx_data, tx_data, data_in, data_out, data, sum_1_in, sum_2_in, sum_1_out, sum_2_out;

uart_rx #(
  .CLOCK_BAUD_RATIO(400),
  .BIT_WIDTH(8)
) rx (
  .clk(clk),
  .rx(rx), // RX line
  .ready(rx_ready), // Is high when data transaction is complete
  .success(rx_success), // Is high if transaction is considered successfull (when stop bit is high)
  .data(rx_data) // Data received
);

uart_tx #(
  .CLOCK_BAUD_RATIO(400),
  .BIT_WIDTH(8)
) tx (
  .clk(clk),
  .rx(rx), // RX line
  .ready(tx_ready), // Is high when data transaction is complete
  .success(tx_success), // Is high if transaction is considered successfull (when stop bit is high)
  .data(tx_data) // Data received
);

  fletcher #(
      .BIT_WIDTH(8)
  ) fletcher_in (
      .reset(reset),
      .check(check_in),
      .data(data),
      .sum_1(sum_1),
      .sum_2(sum_2)
  );

  fletcher #(
      .BIT_WIDTH(8)
  ) fletcher_in (
      .reset(reset),
      .check(check_out),
      .data(data),
      .sum_1(sum_1),
      .sum_2(sum_2)
  );

fifo_memory #(
    .ADDRESS_COUNT(8),
    .BIT_WIDTH(8)
) fifo (
    .clk(clk),
    .reset(reset),
    .write(write),
    .read(read),
    .full(full),
    .empty(empty),
    .data_in(data_in),
    .data_out(data_out)
);

endmodule