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
        parameter BIT_WIDTH = 8,
        parameter LEN_MAX = 8
    )(
        input wire clk, ready, success, tx_ready, reset,
        input wire [BIT_WIDTH-1:0] data_in,
        output reg read, transmit,
        output wire [BIT_WIDTH-1:0] data_out
    );

    reg [2:0] state;

    parameter IDLE = 0;
    parameter WAIT = 1;
    parameter SEND = 2;
    parameter READ = 3;
    parameter EMPT = 4;

    reg [$clog2(LEN_MAX)-1:0] n = 0;
    reg [$clog2(LEN_MAX)-1:0] i = 0;

    assign data_out = data_in;

    always @(posedge clk, posedge reset) begin
        state <= state;
        read <= 0;
        transmit <= 0;

        if (reset) begin // Reset called
            state <= IDLE;
        end

        else begin
        case(state)
            IDLE: begin
                if (ready & success) begin // Wait for ready fifo
                    state <= WAIT;
                end
            end

            WAIT: begin
                if (tx_ready) begin // Wait until tx is ready for transmission
                    transmit <= 1;
                    state <= SEND;
                end
            end

            SEND: begin // Pop fifo
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

            default: state <= IDLE;
        endcase
        end
    end

endmodule
