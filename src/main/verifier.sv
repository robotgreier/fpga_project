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
        input wire clk, rx_ready, rx_success, master_reset, fifo_full,
        input wire [BIT_WIDTH-1:0] rx_data,
        input wire [(BIT_WIDTH*2)-1:0] fletcher_sum,
        output reg ready, success, write, check, reset
    );

    // State parameters
    parameter IDLE = 0;
    parameter LEN = 1;
    parameter DATA = 2;
    parameter CHECK_1_WAIT = 3;
    parameter CHECK_2_WAIT = 4;
    parameter CHECK = 5;

    reg [2:0] state;
    reg [$clog2(LEN_MAX)-1:0] n = 0;
    reg [$clog2(LEN_MAX)-1:0] i = 0;

    reg [7:0] checksum_1;
    reg [7:0] checksum_2;

    always @(posedge clk, master_reset) begin
        if (master_reset) begin // Reset
            state <= IDLE;
            n <= 0;
            i <= 0;
        end

        else begin // Clock
            state <= state;
            ready <= 0;
            success <= 0;
            write <= 0;
            check <= 0;
            reset <= 0;

            case (state)
                IDLE: begin
                    if (rx_ready & rx_success) begin // CMD Packet received
                        write <= 1; // Write CMD to fifo
                        check <= 1; // Add CMD to fletcher
                        state <= LEN; // Transition to LEN
                        n <= 0;
                        i <= 0;
                    end
                end

                LEN: begin
                    if (rx_ready & rx_success) begin // LEN Packet received
                        n <= rx_data; // Store LEN as n
                        write <= 1; // Write LEN to fifo
                        check <= 1; // Add CMD to fletcher
                        state <= DATA; // Transition to LEN
                    end
                end

                DATA: begin
                    if (i >= n) begin // All packets received
                        state <= CHECK_1_WAIT; // Transition to CHECK_1_WAIT
                    end
                    else begin // Packets remaining
                        if (rx_ready & rx_success) begin // New packet ready
                            write <= 1; // Write packet to fifo
                            check <= 1; // Add packet to fletcher
                            i = i + 1; // Increment counter
                        end
                    end
                end

                CHECK_1_WAIT: begin // Wait for checksum packet to arrive
                    if (rx_ready & rx_success) begin // First checksum packet received
                        checksum_1 <= rx_data; // Store received checksum
                        check <= 1; // Add packet to fletcher, ignore fifo
                        state <= CHECK_2_WAIT; // Transition to CHECK_2_WAIT
                    end
                end

                CHECK_2_WAIT: begin
                    if (rx_ready & rx_success) begin // Last checksum packet received
                    checksum_2 <= rx_data; // Store received checksum
                        check <= 1; // Add packet to fletcher, ignore fifo
                        state <= CHECK; // Transition to CHECK
                    end
                end

                CHECK: begin
                    reset <= 1; // Reset fletcher
                    ready <= 1; // Tell master system is ready
                    success <= ({checksum_1, checksum_2} == fletcher_sum); // Tell master it was success
                    state <= IDLE;
                end
            endcase

            if ((rx_ready & !rx_success) || fifo_full) begin
                state <= IDLE;
                reset <= 1;
                ready <= 1;
                success <= 0;
            end
        end
    end

endmodule
