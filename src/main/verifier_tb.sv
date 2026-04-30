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


module verifier_tb(

    );

    reg clk, rx_ready, rx_success, master_reset, fifo_full;
    reg [7:0] rx_data;
    reg [15:0] fletcher_sum;
    wire ready, success, write, check, reset;

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
        .ready(ready),
        .success(success),
        .write(write),
        .check(check),
        .reset(reset)
    );

    initial begin // Initial values and clock
        clk = 0;
        rx_ready = 0;
        rx_success = 0;
        master_reset = 0;
        fifo_full = 0;
        rx_data = 0;
        fletcher_sum = 16'h25E7;

        repeat(100) #5 clk = ~clk;
    end

    initial begin // Master
        #5
        master_reset = 1;
        #5
        master_reset = 0;
        // #1

    end

    initial begin // RX
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
