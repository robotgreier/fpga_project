module fifo_memory #(
  parameter ADDRESS_COUNT = 256, // Must be in power of two
  parameter BIT_WIDTH = 8
)(
  input wire clk,
  input wire soft_reset, // Sets pointers to default value
  input wire hard_reset, // Sets pointers to default value
  input wire write, // Writes data at current write pointer and increments pointer
  input wire commit, // Writes data at current write pointer and increments pointer
  input wire read, // Increments current read pointer
  input wire [BIT_WIDTH-1:0] data_in,
  output logic full,
  output logic empty,
  output reg [BIT_WIDTH-1:0] data_out // Read data
);

reg [$clog2(ADDRESS_COUNT)-1:0] read_pointer;
reg [$clog2(ADDRESS_COUNT)-1:0] write_pointer;
reg [$clog2(ADDRESS_COUNT)-1:0] commit_pointer;

reg [BIT_WIDTH-1:0] memory [0:ADDRESS_COUNT-1];

assign full = (write_pointer + 1'b1) == read_pointer;
assign empty = commit_pointer == read_pointer;


always @ (posedge clk or posedge soft_reset or posedge hard_reset) begin
    data_out <= memory[read_pointer];

    if (hard_reset) begin
        read_pointer <= 0;
        write_pointer <= 0;
        commit_pointer <= 0;
    end

    else if (soft_reset) begin // Reset
        write_pointer <= commit_pointer;
    end

    else begin // CLK

        if (write && !full) begin
            memory[write_pointer] <= data_in;
            write_pointer <= write_pointer + 1;
        end

        if (read && !empty) begin
            read_pointer <= read_pointer + 1;
        end

        if (commit) begin
            commit_pointer <= write_pointer;
        end
    end
end
endmodule