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
        parameter LEN_MAX = 8,
        parameter WEIGHT_SELECT = 128,
        parameter DATA_SELECT = 3
    )(
        input wire clk, reset, empty, err_empty,
        input wire [BIT_WIDTH-1:0] data_in,
        output reg read, write, commit, master_reset,
        output wire [BIT_WIDTH-1:0] data_out,
        output wire [$clog2(WEIGHT_SELECT)-1:0] weight_select,
        output wire [$clog2(DATA_SELECT)-1:0] data_select
    );

    // SNN data address map:
    // 0-127: Weights (128 bytes)
    // 199: Dopamine level (1 byte)
    // 200-211: spike data (11 bytes - 32/3 ~ 11) - each byte contains 3 spikes with 2 bits each, and 2 bits unused

    reg [7:0] state;

    localparam IDLE = 0;
    localparam CMD = 1;
    localparam INIT = 2;
    localparam INIT_LOOP = 3;
    localparam INIT_ERROR = 4;
    localparam SPIKE = 5;
    localparam SPIKE_LOOP = 6;
    localparam SPIKE_WRITE = 7;
    localparam SPIKE_SEND = 8;
    localparam DOPAMINE = 9;
    localparam STOP = 10;
    localparam STOP_SEND = 11;
    localparam STOP_LOOP = 12;
    localparam STOP_COMMIT = 13;
    localparam RESET = 14;
    localparam ERROR = 15;
    localparam ERROR_FIX = 16;
    localparam WRITE_ERROR_1 = 17;
    localparam WRITE_ERROR_2 = 18;
    localparam WRITE_ERROR_3 = 19;

    reg [$clog2(LEN_MAX)-1:0] n = 0;
    reg [$clog2(LEN_MAX)-1:0] i = 0;

    always @(posedge clk, posedge reset, posedge err_empty) begin
        state <= state;
        read <= 0;
        write <= 0;
        commit <= 0;
        master_reset <= 0;
        data_out <= 0;

        if (reset) begin // Reset called
            state <= IDLE;
            weight_select <= 0;
            data_select <= 0;
        end

        else if (err_empty) master_reset <= 1;

        else begin
        case(state)
            IDLE: begin
                if (!empty) state <= CMD;

            end

            default: state <= IDLE;
        endcase
        end
    end

endmodule
