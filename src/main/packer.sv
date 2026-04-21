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
    localparam START = 1;
    localparam CMD = 2;
    localparam LEN = 3;
    localparam DATA = 4;
    localparam SUM = 5;

    localparam SOF = 255;
    
    reg [BIT_WIDTH-1:0] state, len, i;
    reg [(BIT_WIDTH*2)-1:0] sum;

    always @(posedge clk, posedge reset) begin
        if (reset) begin // Reset
            fletcher_reset <= 1;
        end
        else begin // Clk
        transmit <= 0;
        check <= 0;
        fifo_reset <= 0;
        fletcher_reset <= 0;
        read <= 0;
        data <= 0;

            case(state)
                IDLE: begin
                    if (master_transmit) begin
                        state <= START;
                    end
                end

                START: begin
                    if (ready) begin
                        transmit <= 1;
                        check <= 1;
                        data <= SOF;
                        state <= CMD;
                    end
                end

                CMD: begin
                    if (ready) begin
                        transmit <= 1;
                        check <= 1;
                        read <= 1;
                        data <= fifo_data;
                        state <= LEN;
                    end
                end

                LEN: begin
                    if (ready) begin
                        transmit <= 1;
                        check <= 1;
                        read <= 1;
                        data <= fifo_data;
                        len <= fifo_data;
                        i <= 0;
                        state <= DATA;
                    end
                end

                DATA: begin
                    if (i < len) begin
                        if (ready) begin
                            transmit <= 1;
                            check <= 1;
                            read <= 1;
                            data <= fifo_data;
                            i <= i + 1;
                            state <= DATA;
                        end
                    end
                    else begin
                        if (ready) begin
                            transmit <= 1;
                            data <= sum[(BIT_WIDTH*2)-1:BIT_WIDTH];
                            state <= SUM;
                        end
                    end
                end

                SUM: begin
                    if (ready) begin
                        transmit <= 1;
                        data <= sum[BIT_WIDTH-1:0];
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
