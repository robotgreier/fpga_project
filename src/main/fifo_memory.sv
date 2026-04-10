module fifo_memory #(
  parameter ADDRESS_COUNT = 256, // Must be in power of two
  parameter BIT_WIDTH = 8
)(
  input wire clk,
  input wire reset, // Sets pointers to default value
  input wire write, // Writes data at current write pointer and increments pointer
  input wire read, // Increments current read pointer
  input wire [BIT_WIDTH-1:0] data_in, // Write data
  output reg full, // TX line
  output reg empty, // Is high when module is idle
  output reg [BIT_WIDTH-1:0] data_out // Read data
);

reg [$clog2(ADDRESS_COUNT)-1:0] read_pointer;
reg [$clog2(ADDRESS_COUNT)-1:0] write_pointer;

reg [BIT_WIDTH-1:0] memory [0:ADDRESS_COUNT-1];

always @ (posedge clk or posedge reset) begin
    data_out <= 0;
    full <= 0;
    empty <= 0;

    if (reset) begin // Reset
        read_pointer <= 0;
        write_pointer <= 0;
    end

    else begin // CLK

        if (write) begin
            if ((write_pointer + 1) == read_pointer) full <= 1;
            else begin
                memory[write_pointer] <= data_in;
                write_pointer <= write_pointer + 1;
            end
        end

        if (read) begin
            if (read_pointer == write_pointer) empty <= 1;
            else begin
                data_out <= memory[read_pointer];
                read_pointer <= read_pointer + 1;
            end
        end
    end
end
endmodule