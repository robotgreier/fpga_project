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
        output reg [BIT_WIDTH-1:0] data_out,
        output reg [BIT_WIDTH-1:0] address_out,
        output reg [$clog2(WEIGHT_SELECT)-1:0] weight_select,
        output reg [$clog2(DATA_SELECT)-1:0] data_select
    );

    // SNN data address map:
    // 0-127: Weights (128 bytes)
    // 199: Dopamine level (1 byte)
    // 200-210: spike data (11 bytes - 32/3 ~ 11) - each byte contains 3 spikes with 2 bits each, and 2 bits unused

    reg [7:0] state;
    reg [7:0] err;

    // Constants
    localparam WEIGHT_START = 0;
    localparam WEIGHT_STOP = 127;
    localparam DOPAMINE_START = 199;
    localparam DOPAMINE_STOP = 199;
    localparam SPIKE_START = 200;
    localparam SPIKE_STOP = 210;
    localparam NO_ADDRESS = 255;

    // State parameters
    localparam IDLE = 0;
    localparam CMD = 1;
    localparam INIT = 2;
    localparam INIT_LOOP = 3;
    localparam SPIKE = 4;
    localparam SPIKE_LOOP = 5;
    localparam SPIKE_WRITE = 6;
    localparam SPIKE_SEND = 7;
    localparam SPIKE_COMMIT = 8;
    localparam DOPAMINE = 9;
    localparam DOPAMINE_WRITE = 10;
    localparam STOP = 11;
    localparam STOP_SEND = 12;
    localparam STOP_LOOP = 13;
    localparam STOP_COMMIT = 14;
    localparam RESET = 15;
    localparam ERROR = 16;
    localparam ERROR_PASS = 17;
    localparam ERROR_FIX = 18;
    localparam WRITE_ERROR_1 = 19;
    localparam WRITE_ERROR_2 = 20;
    localparam WRITE_ERROR_3 = 21;
    localparam CMD_ERROR = 22;

    // Command parameters
    localparam CMD_INIT = 0;
    localparam CMD_SPIKE = 1;
    localparam CMD_DOPAMINE = 2;
    localparam CMD_STOP = 3;
    localparam CMD_RESET = 4;
    localparam CMD_ERR = 5;

    // Error parameters
    localparam ERR_CMD = 0;
    localparam ERR_SPIKE = 1;
    localparam ERR_WEIGHT = 2;

    // MUX select parameters
    localparam WEIGHT_DATA = 0;
    localparam SPIKE_DATA = 1;
    localparam MASTER_DATA = 2;

    reg [$clog2(LEN_MAX)-1:0] n;
    reg [$clog2(LEN_MAX)-1:0] i;

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
            err <= 0;
            address_out <= 255;
            n <= 0;
            i <= 0;
        end

        else if (err_empty) master_reset <= 1;

        else begin
        case(state)
            IDLE: if (!empty) state <= CMD;

            CMD: begin 
                read <= 1;
                case(data_in)
                    CMD_INIT: state <= INIT;
                    CMD_SPIKE: state <= SPIKE;
                    CMD_DOPAMINE: state <= DOPAMINE;
                    CMD_STOP: state <= STOP;
                    CMD_RESET: state <= RESET;
                    CMD_ERR: state <= ERROR;
                    default: begin
                        state <= WRITE_ERROR_1;
                        err <= 0;
                    end
                endcase                n <= 211;
            end

            INIT: begin
                read <= 1;
                i <= WEIGHT_START;
                state <= INIT_LOOP;
            end

            INIT_LOOP: begin
                i = i + 1;
                address_out <= i;
                read <= 1;

                state <= state;
                if (i >= WEIGHT_STOP) state <= IDLE;
                else if (empty) begin
                    state <= WRITE_ERROR_1;
                    err <= 1;
                end
            end

            SPIKE: begin
                i <= SPIKE_START;
                read <= 1;
                state <= SPIKE_LOOP;
            end

            SPIKE_LOOP: begin
                i = i + 1;
                address_out <= i;
                read <= 1;

                state <= state;
                if (i >= SPIKE_STOP) state <= SPIKE_WRITE;
                else if (empty) begin
                    state <= WRITE_ERROR_1;
                    err <= 1;
                end
            end

            SPIKE_WRITE: begin
                data_select <= MASTER_DATA;
                data_out <= 0;
                write <= 1;
                state <= SPIKE_SEND;
            end

            SPIKE_SEND: begin
                write <= 1;
                data_out <= 1;
                state <= SPIKE_COMMIT;
            end

            SPIKE_COMMIT: begin
                data_select <= SPIKE_DATA;
                write <= 1;
                commit <= 1;
                state <= IDLE;
            end

            DOPAMINE: begin
                read <= 1;
                state <= DOPAMINE_WRITE;
            end

            DOPAMINE_WRITE: begin
                address_out <= DOPAMINE_START;
                read <= 1;
                state <= IDLE;
            end

            STOP: begin
                data_select <= MASTER_DATA;
                data_out <= 1;
                write <= 1;
                state <= STOP_SEND;
            end

            STOP_SEND: begin
                data_out <= (WEIGHT_STOP - WEIGHT_START) + 1;
                write <= 1;
                i <= WEIGHT_START;
                state <= STOP_LOOP;
            end

            STOP_LOOP: begin
                i = i + 1;
                data_select <= WEIGHT_DATA;
                weight_select <= i;
                write <= 1;

                state <= state;
                if (i >= WEIGHT_STOP) state <= STOP_COMMIT;
            end

            STOP_COMMIT: begin
                commit <= 1;
                state <= IDLE;
            end

            RESET: begin
                state <= IDLE;
                master_reset <= 1;
            end

            ERROR: begin
                read <= 1;
                state <= RESET;
            end

            ERROR_PASS: begin
                read <= 1;
                state <= ERROR_FIX;
            end

            ERROR_FIX: begin
                read <= 1;
                
                case (data_in)
                    ERR_SPIKE: state <= SPIKE;
                    ERR_WEIGHT: state <= STOP;
                    default: state <= IDLE;
                endcase
            end

            default: state <= IDLE;
        endcase

        if (err_empty) master_reset <= 1;
        end
    end

endmodule
