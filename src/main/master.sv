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
    parameter TRAN = 1;
    parameter READ = 2;
    parameter WAIT_1 = 3;
    parameter WAIT_2 = 4;
    parameter EMPT = 5;

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
                    state <= TRAN;
                end
            end

            TRAN: begin
                if (tx_ready) begin // Wait until tx is ready for transmission
                    transmit <= 1;
                    state <= READ;
                end
            end

            READ: begin // Pop fifo
                state <= WAIT_1;
                read <= 1;
            end

            WAIT_1: begin
                state <= WAIT_2;
            end

            WAIT_2: begin
                n <= data_in;
                i <= 0;
                state <= EMPT;
            end

            EMPT: begin
                if (i <= n) begin
                    i <= i + 1;
                    read <= 1;
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
