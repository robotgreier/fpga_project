# SPIKE – FPGA SNN Implementation
 
SystemVerilog implementation of the spiking neural network (SNN) used in **SPIKE**, an autonomous taskbot that compares the same reward-modulated SNN running as Python software on a Raspberry Pi 4 and as hardware on an Arty A7-100T FPGA.
 
The design implements leaky integrate-and-fire (LIF) neurons with on-chip reward-modulated STDP (R-STDP) and winner-take-all output, and communicates with the Raspberry Pi over UART at 250,000 baud. It uses general-purpose logic only (no DSP slices, no block RAM, no vendor IP in the SNN core). It produces bit-identical outputs to the Python software emulation in [python_neural_network](https://github.com/robotgreier/python_neural_network).
 
## Relation to the paper
 
| Paper section | Content in this repository |
|---|---|
| §2.2 From Sensing to Action (Eq. 1–2) | `src/SNN_core/` – LIF neurons, synapses with eligibility traces and reward, WTA |
| §2.3 One Network, Two Hardware Substrates | `src/main/` – UART, framing, FIFOs, weight and spike loaders |
| §3.1 Isolated Inference Performance | Timing and utilization (50 MHz, single-cycle inference, 12,283 LUTs) |
 
## Target
 
| Item | Value |
|---|---|
| Board | Digilent Arty A7-100T |
| Device | `xc7a100tcsg324-2` |
| Tool | AMD Vivado 2025.2 |
| SNN clock | 50 MHz |
| UART | 250,000 baud |
 
## Repository structure
 
```
src/
├── SNN_core/
│   ├── SNN_core.sv                 # Top-level SNN: synapses, neurons, WTA
│   ├── WTA.sv                      # Winner-take-all with membrane tie-break
│   ├── LIF_core/LIF_core.sv        # LIF neuron (subtractive leak, refractory period)
│   └── synapse_core/               # Synapse, eligibility trace, reward application
├── main/
│   ├── main.sv                     # Top level (SNN parameters set here)
│   ├── master.sv                   # Control state machine
│   ├── uart_rx.sv, uart_tx.sv      # UART interface
│   ├── fletcher.sv, verifier.sv    # Fletcher checksum and packet verification
│   ├── packer.sv, fifo_memory.sv   # Packet framing and buffering
│   ├── spike_loader.sv, weight_loader.sv, dopamine_loader.sv, weight_dumper.sv
│   └── tb_*.sv, *_tb.sv            # Testbenches
└── Arty-A7-100-Master.xdc          # Pin constraints
vivado_project.tcl                   # Script to recreate the Vivado project
main_pin_uart.bit                    # Bitstream, UART on Pmod pins
main_usb_uart.bit                    # Bitstream, UART over the USB port
```
 
## Rebuilding the project
 
1. Clone the repository:
```bash
git clone https://github.com/robotgreier/fpga_project.git
```
2. Open Vivado 2025.2, then in the Tcl Console:
```tcl
cd <path>/fpga_project
source vivado_project.tcl
```
3. Run synthesis, implementation, and bitstream generation.
To program the board directly, open the Hardware Manager and load one of the included bitstreams: `main_usb_uart.bit` for UART over USB, or `main_pin_uart.bit` for UART on the Pmod pins (as used on the taskbot).
 
## Simulation
 
Each module has a testbench (`tb_*.sv` or `*_tb.sv`). Run them in the Vivado simulator by setting the testbench as simulation top, or with any SystemVerilog simulator.
 
## SNN parameters
 
The SNN parameters are set as module parameters in `src/main/main.sv` and match Table 2 of the paper:
 
| Parameter | Value |
|---|---|
| Leak (`DECAY`) | 400 |
| Threshold | 750 |
| Reset | 100 |
| Refractory period | 1 |
| Learning rate (`LR_SHIFT`) | 5 |
| Pre/post windows | 3 / 1 |
| Eligibility decay (`TAU_E_SHIFT`) | 2 |
| Eligibility increment/decrement | +10 / −8 |
| Weight range | [16, 254] |
 
## Related repositories
 
- [ros2](https://github.com/robotgreier/ros2) – ROS 2 workspace for the taskbot, including the UART node that talks to this design
- [python_neural_network](https://github.com/robotgreier/python_neural_network) – Python software emulation of the same SNN
## Citation
 
E. Holm, H. Torkildsen, G. J. Arason, J. K. Dall, B. Nossum, and A. Muhtaroglu, "R-STDP-Based Biomimetic Robot Navigation: A System-Level Energy and Latency Analysis," submitted to *Biomimetics* (MDPI), 2026.
 
## License
 
Apache License 2.0 – see [LICENSE](LICENSE).
 
