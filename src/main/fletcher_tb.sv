`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2026 10:34:56 AM
// Design Name: 
// Module Name: fletcher_tb
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


module fletcher_tb(

    );

    reg reset, check;
    reg [7:0] data;
    wire [7:0] sum_1, sum_2;

    int verification_sum_1 = 0;
    int verification_sum_2 = 0;

    fletcher #(
        .BIT_WIDTH(8)
    ) fletch (
        .reset(reset),
        .check(check),
        .data(data),
        .sum_1(sum_1),
        .sum_2(sum_2)
    );

    initial begin
        reset = 0;
        check = 0;
        data = 0;

        #5
        reset = 1;
        #5
        reset = 0;
        data = 254;
        #5
        repeat (300) begin
            #5
            check = 1;
            #1
            verification_sum_1 = (verification_sum_1 + data) % 255;
            verification_sum_2 = (verification_sum_1 + verification_sum_2) % 255;

            $display("Sum 1: %d, Verification 1: %d, Sum 2: %d, Verification 2: %d, Status: %b", sum_1, verification_sum_1, sum_2, verification_sum_2, ((sum_1==verification_sum_1) && (sum_2==verification_sum_2)));

            // if (verification_sum_1 == sum_1) $display("Sum_1 ok");
            // else $display("Sum_1 failure");

            // if (verification_sum_2 == sum_2) $display("Sum_2 ok");
            // else $display("Sum_2 failure");
            #4
            check = 0;

        end
        $finish;
    end
endmodule
