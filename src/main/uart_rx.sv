/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

module uart_rx #(
  parameter CLOCK_BAUD_RATIO = 200,
  parameter BIT_WIDTH = 8
)(
  input wire clk,
  input wire rx, // RX line
  output reg ready, // Is high when data transaction is complete
  output reg success, // Is high if transaction is considered successfull (when stop bit is high)
  output reg [BIT_WIDTH-1:0] data // Data received
);
// Wires
wire start_out, bit_out, rx_falling;

// Parameters
  parameter IDLE = 2'b00;
  parameter START = 2'b01;
  parameter BIT = 2'b11;
  parameter STOP = 2'b10;

// Regs
  reg start_rst, bit_rst, rx_ff1, rx_ff2, rx_ff3;
  reg [1:0] current_state = IDLE, next_state = IDLE;
  reg [$clog2(BIT_WIDTH):0] n = 0;
  reg [BIT_WIDTH-1:0] temp_data = 0;

  timer #(.times(CLOCK_BAUD_RATIO/2)) start_delay (
    .in(clk),
    .rst(start_rst),
    .out(start_out)
  );

  timer #(.times(CLOCK_BAUD_RATIO)) bit_delay (
    .in(clk),
    .rst(bit_rst),
    .out(bit_out)
  );

  always @(posedge clk) begin
    rx_ff1 <= rx;
    rx_ff2 <= rx_ff1;
    rx_ff3 <= rx_ff2;
  end

  assign rx_falling = (rx_ff3) && (!rx_ff2);

  always @(posedge clk) begin
    current_state <= next_state;
    start_rst <= 1'b0;
    bit_rst <= 1'b0;
    ready <= 1'b0;
    success <= 1'b0;
    case (current_state)
      IDLE: start_rst <= 1'b1;
      START: bit_rst <= 1'b1;
      BIT: begin
        if (bit_out) begin
          temp_data[n] <= rx;
          n <= n + 1;
        end
      end
      STOP: begin
        if (bit_out) begin
          ready <= 1'b1;
          success <= rx;
          data <= temp_data;
          n <= 1'b0;
        end
      end
    endcase
  end

  always @* begin
    next_state = current_state;
    case (current_state)
      IDLE: if (rx_falling) next_state = START;
      START: if (start_out) next_state = BIT;
      BIT: if (n >= BIT_WIDTH) next_state = STOP;
      STOP: if (bit_out) next_state = IDLE;
    endcase
  end
endmodule