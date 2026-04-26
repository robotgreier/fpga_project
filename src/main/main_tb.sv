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
        repeat (5000000) #5 clk = ~clk;
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

        send_byte(255); // SOF
        send_byte(0); // CMD = INIT
        send_byte(128); // N = 128

        repeat(128) begin // DATA
            send_byte(0);
        end

        send_byte(128); // CHECKSUM 1
        send_byte(192); // CHECKSUM 2

        #(400*200);
        
        send_byte(255); // SOF
        send_byte(1); // CMD = SPIKE
        send_byte(11); // N = 11

        repeat(11) begin // DATA
            send_byte(0);
        end

        send_byte(12); // CHECKSUM 1
        send_byte(145); // CHECKSUM 2

        #(400*200);
        $finish;
    end
endmodule
