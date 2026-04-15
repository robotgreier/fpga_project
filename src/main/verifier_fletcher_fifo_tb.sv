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
    wire verifier_ready, verifier_success, verifier_write, verifier_commit, verifier_check, verifier_soft_reset, verifier_hard_reset; // verifier signals
    wire [15:0] fletcher_sum; // fletcher signals
    wire fifo_full, fifo_empty;
    wire [7:0] fifo_data; // fifo signals

    verifier #(
        .BIT_WIDTH(8),
        .LEN_MAX(32)
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
        .commit(verifier_commit),
        .check(verifier_check),
        .soft_reset(verifier_soft_reset),
        .hard_reset(verifier_hard_reset)
    );

    fletcher #(
        .BIT_WIDTH(8)
    ) fletch (
        .reset(verifier_soft_reset),
        .check(verifier_check),
        .data(rx_data),
        .sum(fletcher_sum)
    );

    fifo_memory #(
        .BIT_WIDTH(8),
        .ADDRESS_COUNT(32)
    ) fifo (
        .clk(clk),
        .soft_reset(verifier_soft_reset),
        .hard_reset(verifier_hard_reset),
        .write(verifier_write),
        .commit(verifier_commit),
        .read(master_read),
        .full(fifo_full),
        .empty(fifo_empty),
        .data_in(rx_data),
        .data_out(fifo_data)
    );

    initial begin // Initial values and clock
        clk = 0;
        rx_ready = 0;
        rx_success = 0;
        rx_data = 0;
        master_reset = 0;
        master_read = 0;

        repeat(200) #5 clk = ~clk;
    end

    initial begin // Runtime
        #5
        master_reset = 1;
        #5
        master_reset = 0;

        #25 // Garbage
        rx_ready = 1;
        rx_success = 1;
        rx_data = 8'b00101000;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // Garbage
        rx_ready = 1;
        rx_success = 1;
        rx_data = 8'b00001100;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // Garbage
        rx_ready = 1;
        rx_success = 1;
        rx_data = 8'b11100000;
        #5
        rx_ready = 0;
        rx_success = 0;
        
        #25 // Garbage
        rx_ready = 1;
        rx_success = 1;
        rx_data = 8'b00000000;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // SOF
        rx_ready = 1;
        rx_success = 1;
        rx_data = 8'b10101010;
        #5
        rx_ready = 0;
        rx_success = 0;

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
        rx_data = 19;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 1
        rx_ready = 1;
        rx_success = 1;
        rx_data = 100;
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

        #25 // Unwanted SOF
        rx_ready = 1;
        rx_success = 1;
        rx_data = 8'b10101010;
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
        rx_data = 212;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // Checksum 2
        rx_ready = 1;
        rx_success = 1;
        rx_data = 91;
        #5
        rx_ready = 0;
        rx_success = 0;



        #25 // SOF
        rx_ready = 1;
        rx_success = 1;
        rx_data = 8'b10101010;
        #5
        rx_ready = 0;
        rx_success = 0;

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
        rx_data = 5; // 3 packets
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 1
        rx_ready = 1;
        rx_success = 1;
        rx_data = 85;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 2
        rx_ready = 1;
        rx_success = 1;
        rx_data = 40;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 3
        rx_ready = 1;
        rx_success = 1;
        rx_data = 90;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 4
        rx_ready = 1;
        rx_success = 1;
        rx_data = 200;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // DATA 5
        rx_ready = 1;
        rx_success = 1;
        rx_data = 1;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // Checksum 1
        rx_ready = 1;
        rx_success = 1;
        rx_data = 81;
        #5
        rx_ready = 0;
        rx_success = 0;

        #25 // Checksum 2
        rx_ready = 1;
        rx_success = 1;
        rx_data = 96;
        #5
        rx_ready = 0;
        rx_success = 0;

        #5
        master_read = 1;
        #5
        master_read = 0;
        #5
        master_read = 1;
        #5
        master_read = 0;
        #5
        master_read = 1;
        #5
        master_read = 0;
        #5
        master_read = 1;
        #5
        master_read = 0;
        #5
        master_read = 1;
        #5
        master_read = 0;
        #5
        master_read = 1;
        #5
        master_read = 0;
        #5
        master_read = 1;
        #5
        master_read = 0;

    end
endmodule
