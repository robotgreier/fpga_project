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

    main #() mains (
        .CLK100MHZ(clk),
        .uart_txd_in(rx),
        .uart_rxd_out(tx),
        .btn_reset(reset)
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
        
        // SPIKE
        send_byte(255); // SOF
        send_byte(1); // CMD = SPIKE
        send_byte(11); // N = 11
        for (int i = 0; i < 11; i++) begin // DATA
            send_byte(i);
        end
        send_byte(67); // CHECKSUM 1
        send_byte(110); // CHECKSUM 2

        #(400*200)

        // STOP
        send_byte(255); // SOF
        send_byte(3); // CMD = STOP
        send_byte(0); // N = 0
        send_byte(3); // CHECKSUM 1
        send_byte(6); // CHECKSUM 2

        // DOPAMINE
        // send_byte(255); // SOF
        // send_byte(2); // CMD = DOPAMINE
        // send_byte(1); // N = 11
        // send_byte(210); // DATA = 210
        // send_byte(213); // CHECKSUM 1
        // send_byte(218); // CHECKSUM 2


        #(400*200);

        // RESET
        send_byte(255); // SOF
        send_byte(4); // CMD = RESET
        send_byte(0); // N = 0
        send_byte(4); // CHECKSUM 1
        send_byte(8); // CHECKSUM 2


        #(400*3000);
        $finish;
    end
endmodule
