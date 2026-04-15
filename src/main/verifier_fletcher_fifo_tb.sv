`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 10:45:47 AM
// Design Name: 
// Module Name: verifier_tb
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


module verifier_fletcher_fifo_tb(

    );

    reg clk, rx_ready, rx_success, master_reset, master_read;
    reg [7:0] rx_data;
    wire verifier_ready, verifier_success, verifier_write, verifier_check, verifier_reset; // verifier signals
    wire [15:0] fletcher_sum; // fletcher signals
    wire fifo_full, fifo_empty;
    wire [7:0] fifo_data; // fifo signals

    verifier #(
        .BIT_WIDTH(8),
        .LEN_MAX(256)
    ) veri (
        .clk(clk),
        .rx_ready(rx_ready),
        .rx_success(rx_success),
        .master_reset(master_reset),
        .fifo_full(fifo_full),
        .rx_data(rx_data),
        .fletcher_sum(fletcher_sum),
        .ready(verifier_ready),
        .success(verifier_success),
        .write(verifier_write),
        .check(verifier_check),
        .reset(verifier_reset)
    );

    fletcher #(
        .BIT_WIDTH(8)
    ) fletch (
        .reset(verifier_reset),
        .check(verifier_check),
        .data(rx_data),
        .sum(fletcher_sum)
    );

    fifo_memory #(
        .BIT_WIDTH(8),
        .ADDRESS_COUNT(256)
    ) fifo (
        .clk(clk),
        .reset(master_reset),
        .write(verifier_write),
        .read(master_read),
        .full(fifo_full),
        .empty(fifo_empty),
        .data_in(rx_data),
        .data_out(fifo_out)
    );

    initial begin // Initial values and clock
        clk = 0;
        rx_ready = 0;
        rx_success = 0;
        rx_data = 0;
        master_reset = 0;
        master_read = 0;

        repeat(100) #5 clk = ~clk;
    end

    initial begin // Runtime
        #5
        master_reset = 1;
        #5
        master_reset = 0;

        #25 // INIT
        rx_ready = 1;
        rx_success = 1;
        rx_data = 0;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // LEN
        rx_ready = 1;
        rx_success = 1;
        rx_data = 5; // 5 packets
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 1
        rx_ready = 1;
        rx_success = 1;
        rx_data = 100; // Weight 1
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 2
        rx_ready = 1;
        rx_success = 1;
        rx_data = 150;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 3
        rx_ready = 1;
        rx_success = 1;
        rx_data = 67;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 4
        rx_ready = 1;
        rx_success = 1;
        rx_data = 230;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 5
        rx_ready = 1;
        rx_success = 1;
        rx_data = 255;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // Checksum 1
        rx_ready = 1;
        rx_success = 1;
        rx_data = 37;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // Checksum 2
        rx_ready = 1;
        rx_success = 1;
        rx_data = 231;
        #5
        rx_ready = 0;
        rx_success = 0;
    end
endmodule
