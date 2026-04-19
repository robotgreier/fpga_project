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
        .clk(clk),
        .rx(rx),
        .reset(reset),
        .tx(tx)
    );

    //--------------------------------
    // Clock generation
    //--------------------------------
    initial begin
        clk = 0;
        repeat (500000) #5 clk = ~clk;
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

        send_byte(8'hAA);
        send_byte(8'h00);
        send_byte(8'h05);
        send_byte(8'd100);
        send_byte(8'd150);
        send_byte(8'd45);
        send_byte(8'd89);
        send_byte(8'd67);
        send_byte(8'h74);
        send_byte(8'h41);

        #(400*200);

        send_byte(170);
        send_byte(1);
        send_byte(3);
        send_byte(10);
        send_byte(50);
        send_byte(145);
        send_byte(124);
        send_byte(37);

        #(400*200);
        
        send_byte(170);
        send_byte(170);
        send_byte(1);
        send_byte(3);
        send_byte(10);
        send_byte(50);
        send_byte(145);
        send_byte(32);
        send_byte(37);

        #(400*200);
        $finish;
    end
endmodule
