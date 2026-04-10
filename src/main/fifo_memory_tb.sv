`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/09/2026 02:18:13 PM
// Design Name: 
// Module Name: fifo_memory_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_memory_tb(
    );

    reg clk, reset, write, read;
    wire full, empty;
    reg [7:0] data_in;
    wire [7:0] data_out;

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

    initial begin
        clk = 1'b0;
        forever begin
            #5 clk = ~clk;
        end
    end

    initial begin
        reset = 1'b0;
        write = 1'b0;
        read = 1'b0;
        data_in = 0;

        #5
        reset = 1;
        #5
        reset = 0;
        #5
        data_in = 1;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 2;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 3;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 4;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 5;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 6;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 7;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 8;
        write = 1;
        #5
        write = 0;
        #5
        data_in = 9;
        write = 1;
        #5
        write = 0;
    end
endmodule
