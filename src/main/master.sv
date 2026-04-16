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
        output wire [DATA_BIT_WIDTH-1:0] data_out
    );

    reg [2:0] state;

    parameter IDLE = 0;
    parameter SEND = 1;
    parameter READ = 2;
    parameter EMPT = 3;

    reg [$clog2(LEN_MAX)-1:0] n = 0;
    reg [$clog2(LEN_MAX)-1:0] i = 0;

    assign data_out = data_in;

    always @(posedge clk) begin
        read <= 0;
        transmit <= 0;
        data_out <= 0;

        case(state)
            IDLE: begin
                if (ready & success) begin // Send CMD along next state
                    transmit <= 1;
                    state <= SEND;
                end
            end

            SEND: begin
                state <= READ;
                read <= 1;
            end

            READ: begin
                n <= data_in;
                i <= 0;
                state <= EMPT;
            end

            EMPT: begin
                if (i < n) begin
                    i <= i + 1;
                    transmit <= 1;
                    state <= EMPT;
                end
                else begin
                    state <= IDLE;
                end
            end
        endcase
    end

endmodule
