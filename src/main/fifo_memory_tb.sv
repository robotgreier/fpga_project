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
        #20
        for (int i = 0; i < 10; i++) begin
            @(negedge clk) begin
                #1
                data_in <= i;
                write <= 1;
            end

            @(posedge clk) begin
                #1
                write <= 0;
            end
        end
        #20
        repeat(10) begin
            @(negedge clk) begin
            #1
            read = 1;
            end
        
            @(posedge clk) begin
            #1
            read = 0;
            end
        end
        #20
        for (int i = 0; i < 10; i++) begin
            @(negedge clk) begin
                #1
                data_in <= i;
                write <= 1;
            end

            @(posedge clk) begin
                #1
                write <= 0;
            end
        end
        #20
        repeat(10) begin
            @(negedge clk) begin
            #1
            read = 1;
            end
        
            @(posedge clk) begin
            #1
            read = 0;
            end
        end
    end
endmodule
