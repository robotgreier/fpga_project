module spike_loader #(
    parameter int N_INPUTS   = 31
    ) (
    input  logic        clk, rst,
    input  logic [7:0]  data,
    input  logic [7:0] adr,
    output logic [(N_INPUTS) - 1:0] spiketrain
);

    localparam int ADR_MIN      = 200;
    localparam int N_CHUNKS     = (N_INPUTS + 2) / 3;  // bytes needed to cover all spikes
    localparam int ADR_MAX      = ADR_MIN + N_CHUNKS - 1;
    localparam int LAST_CHUNK   = N_CHUNKS - 1;
    localparam int TOTAL_SPIKES = N_INPUTS;

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
    // adr=ADR_MIN+0 → bits[TOTAL_SPIKES-1 : TOTAL_SPIKES-3]
    // adr=ADR_MIN+1 → bits[TOTAL_SPIKES-4 : TOTAL_SPIKES-6], etc.
    // After the final chunk is written, spiketrain_temp is committed to spiketrain.
    logic commit;

    always_ff @(posedge clk) begin : get_spike
        if (rst) begin
            spiketrain_temp <= '0;
            spiketrain      <= '0;
            commit          <= '0;
        end else begin
            commit <= '0; 
            if (pair_valid && adr >= ADR_MIN && adr <= ADR_MAX) begin
                spiketrain_temp[TOTAL_SPIKES-1 - 3*(adr - ADR_MIN) -: 3] <= spk_temp;
                if ((adr - ADR_MIN) == LAST_CHUNK)
                    commit <= 1'b1;
            end
            if (commit)
                spiketrain <= spiketrain_temp;
        end
    end

endmodule