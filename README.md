# FPGA Graphics and Compute Accelerator (PYNQ-Z2)

This project implements a command-driven graphics and compute accelerator on the
PYNQ-Z2 (Zynq-7020) FPGA platform. The design explores hardware/software co-design
techniques for GPU-inspired workloads, with a focus on deterministic execution,
explicit command ordering, and clear separation of responsibilities between the
ARM processing system (PS) and programmable logic (PL).

All rendering and compute operations are controlled through a FIFO-based command
stream issued by software running on the ARM CPU. Commands are executed sequentially
and entirely in FPGA hardware.

## Project Goals

- Design a simple but realistic GPU-style command processor
- Implement a fixed-function graphics pipeline in FPGA logic
- Explore hardware scheduling, state management, and handshaking
- Enable Python/Jupyter-based visualization via the PYNQ framework
- Serve as a learning and experimentation platform for FPGA graphics and compute

## High-Level Architecture

![Architecture Diagram](/docs/architecture/Graphics_Compute_Accelerator_Block_Diagram.png)

### Data Flow Overview

1. Software running on the ARM CPU issues commands via an AXI-Lite interface
2. Commands are queued in a FIFO and consumed sequentially by the command processor
3. The command processor:
   - Decodes command headers
   - Buffers payload data
   - Dispatches work to execution units
4. Graphics execution units generate pixel streams
5. A pixel arbiter merges pixel outputs from multiple sources
6. Pixels are written to a framebuffer in external memory
7. Framebuffer contents are displayed via HDMI

## Command Execution Model

The accelerator uses a dispatcher-style execution model:

- Commands are executed strictly in order
- Only one command may be active at a time
- Multi-cycle commands block subsequent commands until completion
- All state changes are explicitly ordered through the command stream

## Current Implementation Status

### Implemented

- FIFO-driven command processor FSM
- Phase-accurate ready/valid protocol
- Stateful commands:
  - SET_COLOR
  - SET_VIEWPORT
- Action commands:
  - CLEAR
  - DRAW_TRIANGLE (bounding-box rasterization)
- Rasterizer with:
  - Bounding box computation
  - Viewport clipping
  - Pixel iteration
- Pixel arbiter (CLEAR and RASTER sources)
- Simulation-time assertions
- Vivado waveform validation

### In Progress / Planned

- Framebuffer controller (BRAM to DDR)
- AXI-based framebuffer writes
- Python/Jupyter visualization on PYNQ
- HDMI output integration
- Z-buffer and depth testing
- SIMD compute core (DISPATCH_SIMD)

## Documentation

Detailed design documentation is located in the `docs/` directory:

- Command Interface Specification  
  [docs/notes/command_model.md](/docs/notes/command_model.md)  
  Defines the command format, execution model, and design invariants.

- Waveform Analysis  
  [docs/waveforms/analysis.md](/docs/waveforms/analysis.md)  
  Annotated waveforms validating command processor and execution units.

- Architecture Diagrams  
  [docs/architecture/](/docs/architecture/)  
  System-level block diagrams of the accelerator.

## Development Environment

- FPGA Platform: PYNQ-Z2 (Zynq-7020)
- Toolchain: Vivado (behavioral simulation)
- Languages: SystemVerilog, Python (planned)
- Simulation: Cycle-accurate RTL simulation with assertions
- Target Runtime: PYNQ Linux with Jupyter Notebook

## Design Philosophy

Key principles guiding this project:

- Deterministic behavior
- Explicit state transitions
- One-command-at-a-time execution
- Clear hardware/software boundaries
- Verifiable behavior through simulation and assertions