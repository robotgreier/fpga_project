`default_nettype none
`timescale 1ns/1ps

module uart_tx_tb;
  // Input
  logic clk = 1'b0;
  logic transmit = 1'b0;
  logic [7:0] data = 8'b00001111;
  logic tx;
  logic ready;

  parameter CLOCK_RATE = 100_000_000;
  parameter BAUD_RATE = 250_000;

  uart_tx #(
    .CLOCK_BAUD_RATIO(CLOCK_RATE/BAUD_RATE),
    .BIT_WIDTH(8)
  ) uart_rx_1 (
    .clk(clk),
    .transmit(transmit),
    .data(data),
    .tx(tx),
    .ready(ready)
  );

  initial begin
    // Dump vars to the output .vcd file
    $dumpvars(0, uart_tx_tb);

    repeat (11000) begin
      #5 clk = ~clk;
    end

    $display("End of simulation");
    $finish;
  end

  initial begin
    #250 transmit = 1'b1;
    #250 transmit = 1'b0;
  end

endmodule
