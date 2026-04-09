module fifo_memory #(
  parameter ADDRESS_COUNT = 256, // Must be in power of two
  parameter BIT_WIDTH = 8
)(
  input wire clk,
  input wire reset, // Sets pointers to default value
  input wire write, // Writes data at current write pointer and increments pointer
  input wire read, // Increments current read pointer
  input wire [BIT_WIDTH-1:0] data_in, // Write data
  output wire full, // TX line
  output wire empty, // Is high when module is idle
  output reg [BIT_WIDTH-1:0] data_out // Read data
);

reg [$clog2(ADDRESS_COUNT)-1:0] read_pointer;
reg [$clog2(ADDRESS_COUNT)-1:0] write_pointer;

reg [BIT_WIDTH-1:0] memory [0:ADDRESS_COUNT-1];

assign full = (write_pointer + 1 == read_pointer);
assign empty = (read_pointer == write_pointer);

always @ (posedge clk or posedge reset) begin

    if (reset) begin // Reset
        read_pointer <= 0;
        write_pointer <= 0;
    end

    else begin // CLK

        data_out <= memory[read_pointer];

        if (write && !full) begin
            memory[write_pointer] <= data_in;
            write_pointer <= write_pointer + 1;
        end

        if (read && !empty) begin
            read_pointer <= read_pointer + 1;
        end
    end
end
endmodule