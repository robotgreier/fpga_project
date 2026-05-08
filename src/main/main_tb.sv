`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/17/2026 12:15:30 PM
// Design Name: 
// Module Name: main_tb
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


module main_tb(

    );

    reg clk, rx, reset;
    wire tx;
    wire [8:0] led;

    main #() mains (
        .CLK100MHZ(clk),
        .uart_txd_in(rx),
        .uart_rxd_out(tx),
        .btn_reset(reset),
        .spk_out_led(led[0]),
        .rst_led(led[1]),
        .fifo_out_empty_led(led[2]),
        .fifo_out_full_led(led[3]),
        .fifo_in_empty_led(led[4]),
        .fifo_in_full_led(led[5]),
        .packer_err_empty_led(led[6]),
        .packer_transmit_led(led[7]),
        .error_led(led[8])
    );

    //--------------------------------
    // Clock generation
    //--------------------------------
    initial begin
        clk = 0;
        repeat (10000000) #5 clk = ~clk;
    end

    //--------------------------------
    // UART byte sender task
    //--------------------------------
    task send_byte(input [7:0] data);
        integer i;
    begin
        rx = 1'b0;              // start bit
        #(400*10);

        for (i = 0; i < 8; i++) begin
            rx = data[i];       // LSB first
            #(400*10);
        end

        rx = 1'b1;              // stop bit
        #(400*10);
    end
    endtask

    //--------------------------------
    // Stimulus
    //--------------------------------
    initial begin
        rx = 1'b1;            // idle
        reset = 0;
        #5
        reset = 1;
        #5
        reset = 0;

        #(400*10);

        // INIT
        send_byte(255); // SOF
        send_byte(0); // CMD = INIT
        send_byte(128); // N = 128
        for (int i = 0; i < 128; i++) begin // DATA
            send_byte(i);
        end
        send_byte(96); // CHECKSUM 1
        send_byte(91); // CHECKSUM 2

        #(400*200);

        send_byte(255);
        send_byte(1);
        send_byte(3);
        send_byte(0);
        send_byte(0);
        send_byte(0);
        send_byte(4);
        send_byte(17);

        #(400*1000);

        $finish;
    end
endmodule
