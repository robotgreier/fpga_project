module main (
  input wire clk
);

wire rx, ready, success, reset, write, read, full, empty;
wire [7:0] data, data_in, data_out;

uart_rx #(
  .CLOCK_BAUD_RATIO(400),
  .BIT_WIDTH(8)
) rx (
  .clk(clk),
  .rx(rx), // RX line
  .ready(ready), // Is high when data transaction is complete
  .success(success), // Is high if transaction is considered successfull (when stop bit is high)
  .data(data) // Data received
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