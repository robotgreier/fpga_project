`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2026 12:35:23 PM
// Design Name: 
// Module Name: verifier
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


module verifier#(
        parameter BIT_WIDTH = 8,
        parameter LEN_MAX = 256
    )(
        input wire clk, rx_ready, rx_success, reset, fifo_full,
        input wire [BIT_WIDTH-1:0] rx_data,
        input wire [(BIT_WIDTH*2)-1:0] fletcher_sum,
        output reg ready, success, write, commit, check, fifo_reset, fletcher_reset
    );

    // State parameters
    parameter IDLE = 0;
    parameter CMD = 1;
    parameter LEN = 2;
    parameter DATA = 3;
    parameter CHECK_1_WAIT = 4;
    parameter CHECK_2_WAIT = 5;
    parameter CHECK = 6;
    parameter RESET = 7;

    parameter SOF = 8'b10101010;

    reg [3:0] state;
    reg [$clog2(LEN_MAX)-1:0] n = 0;
    reg [$clog2(LEN_MAX)-1:0] i = 0;

    reg [7:0] checksum_1;
    reg [7:0] checksum_2;
    reg temp_check;


    always @(posedge clk, posedge reset) begin
        if (reset) begin // Reset
            state <= IDLE;
            n <= 0;
            i <= 0;
            temp_check <= 0;
            fifo_reset <= 1;
            fletcher_reset <= 1;
        end

        else begin // Clock
            state <= state;
            ready <= 0;
            success <= 0;
            write <= 0;
            check <= 0;
            fifo_reset <= 0;
            fletcher_reset <= 0;
            commit <= 0;

            case (state)
                IDLE: begin
                    if (rx_ready & rx_success & (rx_data == SOF)) begin // SOF Packet received and verified
                        check <= 1; // Add SOF to fletcher
                        state <= CMD; // Transition to CMD
                        n <= 0;
                        i <= 0;
                    end
                    // else soft_reset <= 1;
                end

                CMD: begin
                    if (rx_ready & rx_success & (rx_data != SOF)) begin // CMD Packet received
                        write <= 1; // Write CMD to fifo
                        check <= 1; // Add CMD to fletcher
                        state <= LEN; // Transition to LEN
                        n <= 0;
                        i <= 0;
                    end

                end

                LEN: begin
                    if (rx_ready & rx_success & (rx_data != SOF)) begin // LEN Packet received
                        if (rx_data <= LEN_MAX) begin // Check if data is within bounds
                            n <= rx_data; // Store LEN as n
                            write <= 1; // Write LEN to fifo
                            check <= 1; // Add LEN to fletcher
                            state <= DATA; // Transition to DATA
                        end
                        else begin
                            ready <= 1;
                            success <= 0;
                            state <= IDLE;
                        end
                    end
                end

                DATA: begin
                    if (i >= n) begin // All packets received
                        state <= CHECK_1_WAIT; // Transition to CHECK_1_WAIT
                    end
                    else begin // Packets remaining
                        if (rx_ready & rx_success & (rx_data != SOF)) begin // New packet ready
                            write <= 1; // Write packet to fifo
                            check <= 1; // Add packet to fletcher
                            i = i + 1; // Increment counter
                        end
                    end
                end

                CHECK_1_WAIT: begin // Wait for checksum packet to arrive
                    if (rx_ready & rx_success & (rx_data != SOF)) begin // First checksum packet received
                        checksum_1 <= rx_data; // Store received checksum
                        // check <= 1; // Add packet to fletcher, ignore fifo
                        state <= CHECK_2_WAIT; // Transition to CHECK_2_WAIT
                    end
                end

                CHECK_2_WAIT: begin
                    if (rx_ready & rx_success & (rx_data != SOF)) begin // Last checksum packet received
                    checksum_2 <= rx_data; // Store received checksum
                        // check <= 1; // Add packet to fletcher, ignore fifo
                        state <= CHECK; // Transition to CHECK
                    end
                end

                CHECK: begin
                    temp_check <= ({checksum_1, checksum_2} == fletcher_sum);
                    fletcher_reset <= 1;
                    state <= RESET;
                end

                RESET: begin
                    success <= temp_check; // Signal success to master
                    commit <= temp_check; // Signal commit to fifo
                    ready <= 1; // Signal ready to master
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            if ((rx_ready & !rx_success) || fifo_full) begin
                state <= IDLE;
                ready <= 1;
                success <= 0;
                fletcher_reset <= 1;
                fifo_reset <= 1;
            end

            if (rx_ready & rx_success & (rx_data == SOF) & (state != IDLE)) begin // Unexpected SOF
                // if (state == CMD) begin
                //     state <= CMD;
                // end
                // else begin
                    state <= IDLE; // Transition to IDLE
                    fletcher_reset <= 1;
                    fifo_reset <= 1;
                // end
            end
        end
    end

endmodule
