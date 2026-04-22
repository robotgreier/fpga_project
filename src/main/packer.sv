`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2026 11:55:50 AM
// Design Name: 
// Module Name: packer
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


module packer #(
        parameter BIT_WIDTH = 8
    )(
        input wire clk, master_transmit, empty, reset, ready,
        input wire [BIT_WIDTH-1:0] fifo_data,
        input wire [(BIT_WIDTH*2)-1:0] fletcher_sum,
        output reg transmit, check, fifo_reset, fletcher_reset, read,
        output reg [BIT_WIDTH-1:0] data
    );

    localparam IDLE = 0;
    localparam START_WAIT_1 = 2;
    localparam START_WAIT_2 = 3;
    localparam START = 4;
    localparam CMD_WAIT_1 = 5;
    localparam CMD_WAIT_2 = 6;
    localparam CMD = 7;
    localparam LEN_WAIT_1 = 8;
    localparam LEN_WAIT_2 = 9;
    localparam LEN = 10;
    localparam DATA_WAIT_1 = 11;
    localparam DATA_WAIT_2 = 12;
    localparam DATA = 13;
    localparam CHECK_1_WAIT_1 = 14;
    localparam CHECK_1_WAIT_2 = 15;
    localparam CHECK_1 = 16;
    localparam CHECK_2_WAIT_1 = 17;
    localparam CHECK_2_WAIT_2 = 18;
    localparam CHECK_2 = 19;

    localparam SOF = 255;
    
    reg [BIT_WIDTH-1:0] state, len, i;
    reg [(BIT_WIDTH*2)-1:0] sum;

    always @(posedge clk, posedge reset) begin
        if (reset) begin // Reset
            fletcher_reset <= 1;
            state <= IDLE;
        end
        else begin // Clk
        transmit <= 0;
        check <= 0;
        fifo_reset <= 0;
        fletcher_reset <= 0;
        read <= 0;

        case(state)
            IDLE: begin
                fletcher_reset <= 1;
                if (master_transmit) state <= START_WAIT_1;
            end

            START_WAIT_1: state <= START_WAIT_2;

            START_WAIT_2: if (ready) state <= START;

            START: begin
                data <= SOF;
                state <= CMD_WAIT_1;
                transmit <= 1;
                check <= 1;
            end

            CMD_WAIT_1: begin
                state <= CMD_WAIT_2;
            end

            CMD_WAIT_2: if (ready) state <= CMD;

            CMD: begin
                data <= fifo_data;
                transmit <= 1;
                state <= LEN_WAIT_1;
                read <= 1;
                check <= 1;
            end

            LEN_WAIT_1: state <= LEN_WAIT_2;

            LEN_WAIT_2: if (ready) state <= LEN;

            LEN: begin
                len <= fifo_data;
                data <= fifo_data;
                i <= 0;
                transmit <= 1;
                state <= DATA_WAIT_1;
                read <= 1;
                check <= 1;
            end

            DATA_WAIT_1: state <= DATA_WAIT_2;

            DATA_WAIT_2: if (ready) state <= DATA;

            DATA: begin
                i <= i + 1;
                data <= fifo_data;
                transmit <= 1;
                read <= 1;
                check <= 1;
                if (i < len - 1) state <= DATA_WAIT_1;
                else state <= CHECK_1_WAIT_1;
            end

            CHECK_1_WAIT_1: state <= CHECK_1_WAIT_2;

            CHECK_1_WAIT_2: if (ready) state <= CHECK_1;

            CHECK_1: begin
                data <= fletcher_sum[(BIT_WIDTH*2)-1:BIT_WIDTH];
                transmit <= 1;
                state <= CHECK_2_WAIT_1;
            end

            CHECK_2_WAIT_1: state <= CHECK_2_WAIT_2;

            CHECK_2_WAIT_2: if (ready) state <= CHECK_2;

            CHECK_2: begin
                data <= fletcher_sum[BIT_WIDTH-1:0];
                transmit <= 1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase

        if (empty & (state != IDLE)) begin
            state <= IDLE;
        end
        end
    end

endmodule
