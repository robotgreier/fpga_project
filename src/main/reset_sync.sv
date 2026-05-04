`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/04/2026 03:49:02 PM
// Design Name: 
// Module Name: reset_sync
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


module reset_sync (
    input  wire clk,
    input  wire async_reset,   // push button
    output wire reset          // synchronous reset
);

reg [1:0] sync;

always @(posedge clk or posedge async_reset) begin
    if (async_reset)
        sync <= 2'b11;     // async assert
    else
        sync <= {1'b0, sync[1]};
end

assign reset = sync[0];

endmodule
