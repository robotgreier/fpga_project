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
        parameter SPIKE_SELECT = 11,
        parameter DATA_SELECT = 3
    )(
        input wire clk, reset, empty, err_empty, err_full,
        input wire [BIT_WIDTH-1:0] data_in,
        output reg read, write, commit, master_reset, fifo_reset,
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
    localparam WEIGHT_OFFSET = 0;
    localparam WEIGHT_N = WEIGHT_SELECT;
    localparam DOPAMINE_OFFSET = 199;
    localparam DOPAMINE_N = 1;
    localparam SPIKE_OFFSET = 200;
    localparam SPIKE_N = SPIKE_SELECT;
    localparam NO_ADDRESS = 255;

    // State parameters
    localparam IDLE = 0;
    localparam CMD = 1;
    localparam INIT = 2;
    localparam INIT_LOOP = 3;
    localparam INIT_WAIT = 4;
    localparam SPIKE = 5;
    localparam SPIKE_LOOP = 6;
    localparam SPIKE_WRITE = 7;
    localparam SPIKE_SEND = 8;
    localparam SPIKE_COMMIT = 10;
    localparam DOPAMINE = 11;
    localparam DOPAMINE_WRITE = 12;
    localparam DOPAMINE_WAIT = 13;
    localparam STOP = 14;
    localparam STOP_SEND = 15;
    localparam STOP_LOOP = 16;
    localparam STOP_COMMIT = 17;
    localparam RESET = 18;
    localparam ERROR = 19;
    localparam ERROR_PASS = 20;
    localparam ERROR_FIX = 21;
    localparam WRITE_ERROR_1 = 22;
    localparam WRITE_ERROR_2 = 23;
    localparam WRITE_ERROR_3 = 24;
    localparam WRITE_ERROR_4 = 25;
    localparam WRITE_ERROR_5 = 26;
    localparam CMD_ERROR = 27;

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
    localparam ERR_EMPTY = 3;
    localparam ERR_FULL = 4;

    // MUX select parameters
    localparam WEIGHT_DATA = 0;
    localparam SPIKE_DATA = 1;
    localparam MASTER_DATA = 2;

    // reg [$clog2(LEN_MAX)-1:0] n;
    reg [$clog2(LEN_MAX)-1:0] i;

    always @(posedge clk) begin
        read <= 0;
        write <= 0;
        commit <= 0;
        master_reset <= 0;
        data_out <= 0;
        address_out <= NO_ADDRESS;
        fifo_reset <= 0;

        if (reset) begin // Reset called
            state <= IDLE;
            weight_select <= 0;
            data_select <= 0;
            err <= 0;
            address_out <= NO_ADDRESS;
            // n <= 0;
            i <= 0;
        end

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
                        err <= ERR_CMD;
                    end
                endcase
            end

            INIT: begin
                read <= 1;
                i <= 0;
                state <= INIT_LOOP;
            end

            INIT_LOOP: begin
                address_out <= i + WEIGHT_OFFSET;
                read <= 1;

                if (i < WEIGHT_N - 1) begin
                    state <= INIT_LOOP;
                    i <= i +1;
                    if (empty) begin
                        state <= WRITE_ERROR_1;
                        err <= ERR_WEIGHT;
                    end
                end
                else state <= INIT_WAIT;
            end

            INIT_WAIT: state <= IDLE;

            SPIKE: begin
                i <= 0;
                read <= 1;
                address_out <= SPIKE_OFFSET;
                state <= SPIKE_LOOP;
            end

            SPIKE_LOOP: begin
                address_out <= i + 1 + SPIKE_OFFSET;
                read <= 1;

                state <= state;
                if (i >= SPIKE_N - 1) state <= SPIKE_WRITE;
                else if (empty) begin
                    state <= WRITE_ERROR_1;
                    err <= ERR_SPIKE;
                end
                else i = i + 1;
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
                state <= SPIKE_SELECT;
            end

            SPIKE_SELECT: begin
                data_select <= SPIKE_DATA;
                write <= 1;
                state <= SPIKE_COMMIT;
            end

            SPIKE_COMMIT: begin
                commit <= 1;
                state <= IDLE;
            end

            DOPAMINE: begin
                read <= 1;
                state <= DOPAMINE_WRITE;
            end

            DOPAMINE_WRITE: begin
                address_out <= DOPAMINE_OFFSET;
                read <= 1;
                state <= DOPAMINE_WAIT;
            end

            DOPAMINE_WAIT: state <= IDLE;

            STOP: begin
                data_select <= MASTER_DATA;
                data_out <= 1;
                write <= 1;
                read <= 1;
                state <= STOP_SEND;
            end

            STOP_SEND: begin
                data_out <= WEIGHT_N;
                write <= 1;
                i <= 0;
                state <= STOP_LOOP;
            end

            STOP_LOOP: begin
                i <= i + 1;
                data_select <= WEIGHT_DATA;
                weight_select <= i + WEIGHT_OFFSET;

                state <= state;
                if (i >= WEIGHT_N) state <= STOP_COMMIT;
                else write <= 1;
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
                state <= ERROR_PASS;
            end

            ERROR_PASS: begin
                read <= 1;
                state <= ERROR_FIX;
            end

            ERROR_FIX: begin
                read <= 1;
                
                case (data_in)
                    ERR_SPIKE: state <= SPIKE_WRITE;
                    ERR_WEIGHT: state <= STOP;
                    default: state <= IDLE;
                endcase
            end

            WRITE_ERROR_1: begin
                fifo_reset <= 1;
                data_select <= MASTER_DATA;
                state <= WRITE_ERROR_2;
            end

            WRITE_ERROR_2: begin
                data_out <= 2;
                write <= 1;
                state <= WRITE_ERROR_3;
            end

            WRITE_ERROR_3: begin
                data_out <= 1;
                write <= 1;
                state <= WRITE_ERROR_4;
            end

            WRITE_ERROR_4: begin
                data_out <= err;
                write <= 1;
                state <= WRITE_ERROR_5;
            end

            WRITE_ERROR_5: begin
                commit <= 1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase

        if (err_empty) begin
            master_reset <= 1;
            err <= ERR_EMPTY;
            state <= WRITE_ERROR_1;
        end

        if (err_full) begin
            err <= ERR_FULL;
            state <= WRITE_ERROR_1;
        end
        end
    end

endmodule
