`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2026 12:31:38 PM
// Design Name: 
// Module Name: fletcher
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


module fletcher #(
    parameter BIT_WIDTH = 8
)(
    input  wire clk,
    input  wire reset,
    input  wire check,
    input  wire [BIT_WIDTH-1:0] data,
    output reg  [BIT_WIDTH-1:0] sum_1,
    output reg  [BIT_WIDTH-1:0] sum_2
);

localparam MODULO = (1<<BIT_WIDTH)-1;

wire [BIT_WIDTH:0] s1_tmp;
wire [BIT_WIDTH-1:0] s1_next;
wire [BIT_WIDTH:0] s2_tmp;
wire [BIT_WIDTH-1:0] s2_next;

assign s1_tmp = {1'b0,sum_1} + {1'b0,data};

assign s1_next =
    (s1_tmp >= MODULO) ?
        s1_tmp - MODULO :
        s1_tmp[BIT_WIDTH-1:0];

assign s2_tmp = {1'b0,sum_2} + {1'b0,s1_next};

assign s2_next =
    (s2_tmp >= MODULO) ?
        s2_tmp - MODULO :
        s2_tmp[BIT_WIDTH-1:0];

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        sum_1 <= 0;
        sum_2 <= 0;
    end
    else if (check) begin
        sum_1 <= s1_next;
        sum_2 <= s2_next;
    end
end

endmodule
