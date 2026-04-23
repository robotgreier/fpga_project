module timer #( // Emits a rising edge when the count is reached
    parameter int unsigned times
)(
    input wire in,
    input wire rst,
    output reg out
);
    logic [$clog2(times-1):0] count = 0;
    logic [$clog2(times-1):0] measure = times[$clog2(times-1):0];

    always_ff @(posedge in or posedge rst) begin
        if (rst) begin
            count <= 0;
            out <= 0;
        end
        else begin
            if (count >= measure) begin
                count <= 0;
                out <= 1;
            end
            else begin
                count <= count + 1;
                out <= 0;
            end
        end
    end
endmodule