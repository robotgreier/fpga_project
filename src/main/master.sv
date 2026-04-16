`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2026 01:17:12 PM
// Design Name: 
// Module Name: master
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


module master #(
        parameter DATA_BIT_WIDTH = 8,
        parameter LEN_MAX = 8
        // parameter ADDR_BIT_WIDTH = 8
    )(
        input wire clk, ready, success,
        input wire [DATA_BIT_WIDTH-1:0] data_in,
        output reg read, transmit,
        output reg [DATA_BIT_WIDTH-1:0] data_out
    );

    reg [2:0] state;

    parameter IDLE = 0;
    parameter CMD = 1;
    parameter LEN = 2;

    reg [$clog2(LEN_MAX)-1:0] n = 0;
    reg [$clog2(LEN_MAX)-1:0] i = 0;

    always @(posedge clk) begin
        read <= 0;
        transmit <= 0;
        data_out <= 0;

        case(state)
            IDLE: begin
                if (ready & success) begin
                    state <= SEND;
                end
            end

            CMD: begin
            end
        endcase

    end

endmodule
