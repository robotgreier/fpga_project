module main #(
  // SNN parameters
    parameter int DECAY         = 512,
    parameter int THRESHOLD     = 4096,
    parameter int RESET         = 0,
    parameter int LR_SHIFT      = 7,
    parameter int T_PRE         = 2,
    parameter int T_POST        = 2,
    parameter int TAU_E_SHIFT   = 3,
    parameter int DW_POS        = 16,
    parameter int DW_NEG        = -8,
    parameter int W_MIN         = 40,
    parameter int W_MAX         = 254,
    parameter logic [7:0] W_INIT = (W_MIN + W_MAX) / 2,
    parameter bit RESET_WEIGHTS = 0,  // 1: reset wipes weights to W_INIT, 0: weights survive reset
    parameter int LEARNING_MODE = 1,  // 0: None, 1: R-STDP, 2: STDP
    parameter int N_INPUTS      = 31,
    parameter int N_OUTPUTS     = 4,
    parameter int FEEDBACK      = 1,   // 1: append NOR-feedback neuron as extra input
    // Main parameters
    parameter int MAX_DATA      = 256,
    parameter int BIT_WIDTH     = 8 // Must be over N_OUTPUTS
  )(
  input logic CLK100MHZ, uart_txd_in, btn_reset,
  output wire uart_rxd_out,
  output wire [N_OUTPUTS-1:0] spk_out_led,
  output wire rst_led
);

// Params
localparam WEIGHT_N = (N_INPUTS+FEEDBACK)*N_OUTPUTS;
localparam DATA_N = 3;
localparam WEIGHT_DATA = 0;
localparam SPIKE_DATA = 1;
localparam MASTER_DATA = 2;
localparam CLK_RATE = 50000000;
localparam BAUD_RATE = 250000;
localparam CLOCK_BAUD_RATIO = CLK_RATE / BAUD_RATE;
logic [N_OUTPUTS-1:0] spk_out;


assign spk_out_led = spk_out; // Directly drive LEDs from SNN output spikes
assign rst_led = btn_reset; // Drive reset LED from reset button for debugging

// ----------------------- Wires ------------------------------ //
wire  master_read, master_write, master_commit, master_reset, master_fifo_reset; // Master signals
wire  [7:0] master_data, master_address;
wire [$clog2(WEIGHT_N)-1:0] master_weight_select;
logic [BIT_WIDTH-1:0] data_out;
logic [$clog2(DATA_N)-1:0] master_data_select;

wire  verifier_ready, // Verifier signals
      verifier_success,
      verifier_write,
      verifier_commit,
      verifier_fifo_reset,
      verifier_fletcher_reset,
      verifier_check;

wire  packer_transmit, // Packer signals
      packer_check,
      packer_fletcher_reset,
      packer_read,
      packer_err_empty;
wire  [7:0] packer_data;

wire  fifo_in_full, fifo_in_empty; // fifo_in signals
wire  [7:0] fifo_in_data;

wire  fifo_out_full, fifo_out_empty; // fifo_out signals
wire  [7:0] fifo_out_data;

wire  fletcher_in_reset; // fletcher_in signals
wire  [15:0] fletcher_in_sum;

wire  fletcher_out_reset; // fletcher_out signals
wire  [15:0] fletcher_out_sum;

wire  rx_ready, rx_success; // RX signals
wire  [7:0] rx_data;

wire  tx_ready; // TX signals

// ----------------------- Connections ------------------------------ //

wire rx, tx, reset;
reg start_reset, clk;

always @(posedge CLK100MHZ, posedge reset) begin
    if (reset)
        clk <= 1'b0;
    else
        clk <= ~clk;   // toggle every clock edge
end

// assign clk = CLK100MHZ;

assign rx = uart_txd_in;
assign uart_rxd_out = tx;
assign reset = start_reset | master_reset | btn_reset;

// Weight mux
logic [BIT_WIDTH-1:0] weight_out;
logic [((N_INPUTS+FEEDBACK)*N_OUTPUTS*8)-1:0] w_parallel_out;
assign weight_out = w_parallel_out[master_weight_select*8 +: 8];


always_comb begin
    unique case (master_data_select)
        WEIGHT_DATA: data_out = weight_out;
        SPIKE_DATA: data_out = {{BIT_WIDTH-N_OUTPUTS{1'b0}}, spk_out};
        MASTER_DATA: data_out = master_data;
        default: data_out = 0;
    endcase
end

// Reset logic
reg [7:0] reset_counter = 0;
reg already_reset = 0;

always @(posedge clk) begin
  if (already_reset == 1'b0) begin  // Check if system is already delayed
    if (reset_counter >= 60) begin // Check if counter is over 60 cycles
      if (start_reset == 1'b1) begin // Check if reset signal is high
        start_reset <= 1'b0;
        already_reset <= 1'b1;
      end
      else begin
        start_reset <= 1'b1;
      end
    end
    else begin
      reset_counter <= reset_counter + 1'b1;
    end
  end
end

// ----------------------- Verification things ------------------------------ //

master #(
  .BIT_WIDTH(BIT_WIDTH),
  .LEN_MAX(MAX_DATA),
  .WEIGHT_SELECT(WEIGHT_N),
  .DATA_SELECT(DATA_N)
) mas (
  .clk(clk),
  .reset(reset),
  .empty(fifo_in_empty),
  .err_empty(packer_err_empty),
  .data_in(fifo_in_data),
  .read(master_read),
  .write(master_write),
  .commit(master_commit),
  .master_reset(master_reset),
  .data_out(master_data),
  .weight_select(master_weight_select),
  .data_select(master_data_select),
  .address_out(master_address),
  .fifo_reset(master_fifo_reset),
  .err_full(fifo_out_full)
);

uart_rx #(
  .CLOCK_BAUD_RATIO(CLOCK_BAUD_RATIO),
  .BIT_WIDTH(BIT_WIDTH)
) uart_r (
  .clk(clk),
  .rx(rx), // RX line
  .ready(rx_ready), // Is high when data transaction is complete
  .success(rx_success), // Is high if transaction is considered successfull (when stop bit is high)
  .data(rx_data) // Data received
);

uart_tx #(
  .CLOCK_BAUD_RATIO(CLOCK_BAUD_RATIO),
  .BIT_WIDTH(BIT_WIDTH)
) uart_t (
  .clk(clk),
  .tx(tx), // TX line
  .transmit(packer_transmit), // Trigger to send data
  .ready(tx_ready), // Is high when uart is available to transmit
  .data(packer_data) // Data to be sent
);

fletcher #(
    .BIT_WIDTH(BIT_WIDTH)
) fletcher_in (
    .reset(verifier_fletcher_reset),
    .check(verifier_check),
    .data(rx_data),
    .sum(fletcher_in_sum)
);

fifo_memory #(
    .ADDRESS_COUNT(MAX_DATA),
    .BIT_WIDTH(BIT_WIDTH)
) fifo_in (
    .clk(clk),
    .soft_reset(verifier_fifo_reset),
    .hard_reset(reset),
    .write(verifier_write),
    .commit(verifier_commit),
    .read(master_read),
    .full(fifo_in_full),
    .empty(fifo_in_empty),
    .data_in(rx_data),
    .data_out(fifo_in_data)
);

verifier #(
    .BIT_WIDTH(BIT_WIDTH),
    .LEN_MAX(MAX_DATA)
) veri (
    .clk(clk),
    .rx_ready(rx_ready),
    .rx_success(rx_success),
    .reset(reset),
    .fifo_full(fifo_in_full),
    .rx_data(rx_data),
    .fletcher_sum(fletcher_in_sum),
    .ready(verifier_ready),
    .success(verifier_success),
    .write(verifier_write),
    .commit(verifier_commit),
    .check(verifier_check),
    .fifo_reset(verifier_fifo_reset),
    .fletcher_reset(verifier_fletcher_reset)
    );

fletcher #(
    .BIT_WIDTH(BIT_WIDTH)
) fletcher_out (
    .reset(packer_fletcher_reset),
    .check(packer_check),
    .data(packer_data),
    .sum(fletcher_out_sum)
);

fifo_memory #(
    .ADDRESS_COUNT(MAX_DATA),
    .BIT_WIDTH(BIT_WIDTH)
) fifo_out (
    .clk(clk),
    .soft_reset(master_fifo_reset),
    .hard_reset(reset),
    .write(master_write),
    .commit(master_commit),
    .read(packer_read),
    .full(fifo_out_full),
    .empty(fifo_out_empty),
    .data_in(data_out),
    .data_out(fifo_out_data)
);

packer #(
    .BIT_WIDTH(8)
) pack (
    .clk(clk),
    .empty(fifo_out_empty),
    .reset(reset),
    .ready(tx_ready),
    .fifo_data(fifo_out_data),
    .fletcher_sum(fletcher_out_sum),
    .transmit(packer_transmit),
    .check(packer_check),
    .fletcher_reset(packer_fletcher_reset),
    .read(packer_read),
    .data(packer_data),
    .err_empty(packer_err_empty)
);

// ----------------------- SNN things ------------------------------ //

// Two source matrices feed w_syn:
//   w_loaded  : weight_loader's view, updated one byte at a time as INIT bytes
//               stream in over UART.
//   w_learned : SNN_core's view, produced by synapse_core (w_syn + delta_w,
//               clamped to [W_MIN, W_MAX]).
// Mirrors the Python reference (LIF_SNN_network.SNNLayer): load_weights()
// overwrites the matrix wholesale, while forward()/apply_reward() evolves it
// through learning -- the two never write the matrix at the same time.
logic [7:0] w_syn     [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0];
logic [7:0] w_loaded  [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0];
logic [7:0] w_learned [N_OUTPUTS-1:0][(N_INPUTS+FEEDBACK)-1:0];

// master_address points at a weight slot only while INIT_LOOP is streaming
// (0..127 with WEIGHT_OFFSET=0).  weight_loader's accept window is 0..198, so
// any non-weight master phase (DOPAMINE=199, SPIKE=200..210, NO_ADDRESS=255)
// falls through to the SNN driver.
wire load_active = (master_address <= 8'd198);

// weight_loader and the w_syn mux both update on the same posedge, so w_syn
// reads the OLD w_loaded on the last address cycle.  Holding load_active one
// extra cycle lets w_syn capture the now-updated w_loaded before switching to
// w_learned.
logic load_active_prev;
always_ff @(posedge clk) load_active_prev <= load_active;
wire load_active_latched = load_active || load_active_prev;

// Power-on init so weights start at W_INIT after FPGA configuration even when
// RESET_WEIGHTS=0 and reset never wipes them.
initial foreach (w_syn[i,j]) w_syn[i][j] = W_INIT;

always_ff @(posedge clk) begin
  if (RESET_WEIGHTS && reset)
    foreach (w_syn[i,j]) w_syn[i][j] <= W_INIT;
  else if (load_active_latched)
    w_syn <= w_loaded;
  else
    w_syn <= w_learned;
end

// Load weights
// Temp signals
// logic [7:0] master_address; // Placed by master signals

weight_loader #(
    .N_INPUTS(N_INPUTS),
    .N_OUTPUTS(N_OUTPUTS),
    .FEEDBACK(FEEDBACK),
    .W_INIT(W_INIT),
    .RESET_WEIGHTS(RESET_WEIGHTS)
) w_loader (
    .clk(clk),
    .rst(reset),
    .data(fifo_in_data),
    .adr(master_address),
    .w_next(w_loaded)
);


// Dump weights

// w_parallel_out moved to connections section
weight_dumper #(
    .N_INPUTS(N_INPUTS),
    .N_OUTPUTS(N_OUTPUTS),
    .FEEDBACK(FEEDBACK)
) w_dumper (
    .w_syn(w_syn),
    .w_parallel_out(w_parallel_out)
);


// SNN run-enable: fires for exactly one cycle after the last spike byte is latched.
// Keeps the SNN frozen during loading (partial spiketrain) and between packets
// (prevents the network from re-processing the same spiketrain multiple times).
localparam int SPIKE_ADDR_LO = 200;
localparam int SPIKE_ADDR_HI = 210;
logic snn_in_spike_range_prev;
wire  snn_in_spike_range = (master_address >= SPIKE_ADDR_LO && master_address <= SPIKE_ADDR_HI);
always_ff @(posedge clk)
    snn_in_spike_range_prev <= snn_in_spike_range;
wire snn_run = snn_in_spike_range_prev && !snn_in_spike_range;

// Load spikes
// Temp signals
logic [(N_INPUTS) - 1:0] spiketrain;

spike_loader #(
    .N_INPUTS(N_INPUTS)
) s_loader (
    .clk(clk),
    .rst(reset),
    .data(fifo_in_data),
    .adr(master_address),
    .spiketrain(spiketrain)
);

// Temp signals
logic signed [3:0] dopamine;
logic reward_en;

dopamine_loader #(
    // .N_OUTPUTS(N_OUTPUTS) Does not exist
) d_loader (
    .data(fifo_in_data),
    .adr(master_address),
    .dopamine(dopamine),
    .reward_en(reward_en)
);


// Instantiate SNN core
logic [$clog2(N_OUTPUTS)-1:0] winner_idx;
// spk_out moved to connections

SNN_core #(
    .DECAY(DECAY),
    .THRESHOLD(THRESHOLD),
    .RESET(RESET),
    .LR_SHIFT(LR_SHIFT),
    .T_PRE(T_PRE),
    .T_POST(T_POST),
    .TAU_E_SHIFT(TAU_E_SHIFT),
    .DW_POS(DW_POS),
    .DW_NEG(DW_NEG),
    .W_MIN(W_MIN),
    .W_MAX(W_MAX),
    .LEARNING_MODE(LEARNING_MODE),
    .N_INPUTS(N_INPUTS),
    .N_OUTPUTS(N_OUTPUTS),
    .FEEDBACK(FEEDBACK)
) snn (
    .clk(clk),
    .run(snn_run),
    .rst(reset),
    .spiketrain(spiketrain),
    .dopamine(dopamine),
    .reward_en(reward_en),
    .w_syn(w_syn),
    .spk_out(spk_out),
    .winner_idx(winner_idx),
    .w_next(w_learned)
);


endmodule