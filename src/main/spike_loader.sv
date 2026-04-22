module spike_loader #(
    parameter int N_INPUTS  = 31
    ) (
    input  logic        clk, rst, en,
    input  logic [7:0]  data,
    input  logic [7:0] adr,
    input  logic        done,
    output logic [(N_INPUTS) - 1:0] spiketrain
);

    localparam int TOTAL_SPIKES = N_INPUTS;  // 31

    logic [TOTAL_SPIKES-1:0] spiketrain_temp;
    logic [2:0]              spk_temp;
    logic                    pair_valid;

    // Decode 3 spikes from byte (LSB-packed: bits[5:0], bits[7:6] unused)
    always_comb begin
        spk_temp   = 3'b0;
        pair_valid = 1'b1;
        for (int i = 0; i < 3; i++) begin
            automatic logic [1:0] pair = data[2*i +: 2];
            spk_temp[i]   = pair[1];
            if (pair != 2'b11 && pair != 2'b00)
                pair_valid = 1'b0;
        end
    end

    // adr selects which 3-bit chunk of spiketrain to write (MSB-first)
    // adr=0 → bits[TOTAL_SPIKES-1 : TOTAL_SPIKES-3]
    // adr=1 → bits[TOTAL_SPIKES-4 : TOTAL_SPIKES-6], etc.
    always_ff @(posedge clk) begin : get_spike
        if (rst) begin
            spiketrain_temp <= '0;
            spiketrain      <= '0;
        end else if (en && pair_valid) begin
            // Write 3 decoded spikes into the correct chunk
            spiketrain_temp[TOTAL_SPIKES-1 - 3*adr -: 3] <= spk_temp;
        end else if (done) begin
            spiketrain <= spiketrain_temp;
        end
    end

endmodule