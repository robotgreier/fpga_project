module main (
  input wire clk
);

wire rx, ready, success;
wire [7:0] data;

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

endmodule