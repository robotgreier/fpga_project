/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module uart_tx #(
  parameter CLOCK_BAUD_RATIO = 400,
  parameter BIT_WIDTH = 8
)(
  input wire clk,
  input wire transmit, // Set to high when data transmission should begin
  input wire [BIT_WIDTH-1:0] data, // Data to be sent
  output reg tx, // TX line
  output wire ready // Is high when module is idle
);
// Wires
wire tick;

// Parameters
  parameter IDLE = 2'b00;
  parameter INIT = 2'b01;
  parameter SEND = 2'b11;

// Regs
  reg delay_rst;
  reg [BIT_WIDTH+1:0] packet;
  reg [1:0] current_state = IDLE, next_state = IDLE;
  reg [$clog2(BIT_WIDTH+1):0] n = 0;

  timer #(.times(CLOCK_BAUD_RATIO)) delay (
    .in(clk),
    .rst(delay_rst),
    .out(tick)
  );

  assign ready = current_state == IDLE;

  always @(posedge clk) begin
    current_state <= next_state;
    delay_rst <= 1'b0;
    tx <= 1'b1;
    case (current_state)
      IDLE: begin
      end
      INIT: begin
        delay_rst <= 1'b1;
        packet <= {1'b1, data, 1'b0};
        n <= 0;
      end
      SEND: begin
        if (n <= BIT_WIDTH+1)
          tx <= packet[n];
        else
          tx <= 1'b1;

        if (tick && n <= BIT_WIDTH+1)
          n <= n + 1;
      end
      default: begin
        tx <= 1'b1;
      end
    endcase
  end

  always @* begin
    next_state = current_state;
    case (current_state)
      IDLE: if (transmit) next_state = INIT;
      INIT: next_state = SEND;
      SEND: if (n == BIT_WIDTH+2) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end
endmodule