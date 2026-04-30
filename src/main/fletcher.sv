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
    input  wire reset,
    input  wire check,
    input  wire [BIT_WIDTH-1:0] data,
    output wire  [(BIT_WIDTH * 2)-1:0] sum
);

localparam MODULO = (1<<BIT_WIDTH)-1;

reg  [BIT_WIDTH-1:0] sum_1;
reg  [BIT_WIDTH-1:0] sum_2;

wire [BIT_WIDTH:0] temp_sum_1;
wire [BIT_WIDTH:0] temp_sum_2;

assign temp_sum_1 = ({1'b0, sum_1} + {1'b0, data} >= MODULO) ? {1'b0, sum_1} + {1'b0, data} - MODULO: {1'b0, sum_1} + {1'b0, data};
assign temp_sum_2 = ({1'b0, temp_sum_1} + {1'b0, sum_2} >= MODULO) ? {1'b0, temp_sum_1} + {1'b0, sum_2} - MODULO : {1'b0, temp_sum_1} + {1'b0, sum_2};

assign sum = {sum_1, sum_2};

always @(posedge check or posedge reset) begin
    if (reset) begin
        sum_1 <= 0;
        sum_2 <= 0;
    end

    else begin
    sum_1 <= temp_sum_1[BIT_WIDTH-1:0];
    sum_2 <= temp_sum_2[BIT_WIDTH-1:0];
    end
end

endmodule
