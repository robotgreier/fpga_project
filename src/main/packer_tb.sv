`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2026 01:13:21 PM
// Design Name: 
// Module Name: packer_tb
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


module packer_tb(

    );

    reg clk, master_transmit, master_write, master_commit, master_reset; // Simulated master signals
    reg [BIT_WIDTH-1:0] master_data;

    wire tx_ready, tx; // UART signals

    wire [(BIT_WIDTH*2)-1:0] fletcher_sum; // Fletcher signals

    wire fifo_empty, fifo_full; // Fifo signals
    wire [BIT-WIDTH-1:0] fifo_data;

    wire packer_transmit, packer_check, packer_fifo_reset, packer_fletcher_reset, packer_read, // Packer signals
    wire [BIT_WIDTH-1:0] packer_data;

    packer #(
        .BIT_WIDTH(8)
    ) pack (
        .clk(clk),
        .master_transmit(master_transmit),
        .empty(fifo_empty),
        .reset(master_reset),
        .ready(tx_ready),
        .fifo_data(fifo_data),
        .fletcher_sum(fletcher_sum),
        .transmit(packer_transmit),
        .check(packer_check),
        .fifo_reset(packer_fifo_reset),
        .fletcher_reset(packer_fletcher_reset),
        .read(packer_read),
        .data(packer_data)
    );

    fifo_memory #(
        .BIT_WIDTH(8),
        .ADDRESS_COUNT(16)
    ) fifo (
        .clk(clk),
        .soft_reset(packer_fifo_reset),
        .hard_reset(master_reset),
        .write(master_write),
        .commit(master_commit),
        .read(packer_read),
        .full(fifo_full),
        .empty(fifo_empty),
        .data_in(master_data),
        .data_out(fifo_data)
    );

    fletcher #(
        .BIT_WIDTH(8)
    ) fletch (
        .reset(packer_fletcher_reset),
        .check(packer_check),
        .data(packer_data),
        .sum(fletcher_sum)
    );

    uart_tx #(
      .CLOCK_BAUD_RATIO(400),
      .BIT_WIDTH(8)
    ) uart_t (
      .clk(clk),
      .tx(tx), // TX line
      .transmit(packer_transmit), // Trigger to send data
      .ready(tx_ready), // Is high when uart is available to transmit
      .data(packer_data) // Data to be sent
    );

    initial begin
        clk <= 0;
        master_transmit <= 0;
        master_write <= 0;
        master_commit <= 0;
        master_reset <= 0;
        master_data <= 0;
        tx_ready <= 1;

        repeat(10000) begin
            #5 clk = ~clk;
        end
    end

    initial begin
        #10
        master_reset = 1;
        #5
        master_reset = 0;

        #10
        master_write <= 1;
        master_data <= 1;
        #10
        master_data <= 3;
        #10
        master_data <= 1;
        #10
        master_data <= 2;
        #10
        master_data <= 3;
        master_write <= 0;
        master_commit <= 1;
        master_transmit <= 1;
        #10
        master_commit <= 0;
        master_transmit <= 0;
    end

endmodule
