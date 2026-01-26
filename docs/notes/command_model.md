# Command Interface Specification (v1)

## 1. Overview

This document specifies the **v1 command interface** for the GPU-inspired graphics and compute accelerator implemented on the PYNQ-Z2 (Zynq-7020). The interface defines how software running on the ARM CPU submits commands to the FPGA accelerator via a FIFO-based command stream.

The design prioritizes:

* Deterministic execution
* Explicit ordering of state and actions
* Simplicity and debuggability
* Clear separation of software and hardware responsibilities

This interface is intentionally fixed-function and blocking in v1, serving as a foundation for future extensions.

## 2. Execution Model

* Commands are issued by software and consumed sequentially by the FPGA.
* A **dispatcher model** is used: only one command is active at a time.
* Each command executes to completion before the next command is processed.
* State updates and action commands are strictly ordered via the command stream.

Command completion is defined by an explicit `done` signal from the target hardware block.

## 3. Command Stream Structure

Each command consists of:

1. A **fixed-size header** (one word)
2. A **variable-length payload** (zero or more words)

All fields are word-aligned. Payload length is expressed in words and does not include the header.

```
| Header (1 word) | Payload (N words) |
```

## 4. Command Header Format (Conceptual)

Each command header contains the following fields:

* **Opcode**
  Identifies the command type and determines payload interpretation.

* **Payload Length**
  Specifies the number of payload words that follow the header.

* **Reserved / Flags**
  Reserved for future use. Must be set to zero in v1.

### Header Invariants

* Header size is exactly one word
* Header always appears at a word boundary
* Payload immediately follows header
* Payload length is measured in words
* Reserved bits must be zero in v1

## 5. Command Processor FSM Summary

The command processor operates as a finite state machine with the following phases:

1. **IDLE** – Wait for command FIFO to become non-empty
2. **READ_HEADER** – Read and decode command header
3. **READ_PAYLOAD** – Consume payload words (if any)
4. **EXECUTE** – Perform command action, wait for completion, and transition back to IDLE

Payload reading is skipped if payload length is zero.

## 6. State vs Action Commands

Commands are divided into two categories:

### Stateful Commands

These commands update persistent accelerator state that affects later commands.

* `SET_COLOR`
* `SET_VIEWPORT`
* `SET_FRAMEBUFFER`

State commands are executed immediately and complete in a single cycle.

### Action Commands

These commands perform operations using the current state.

* `CLEAR`
* `DRAW_TRIANGLE`
* `DISPATCH_SIMD`

Action commands are typically multi-cycle and block command processing until completion.

## 7. Internal Block Handshake Model

This section describes the internal control interface between the command processor and execution blocks. These interfaces are not exposed to software and exist solely within the FPGA fabric.

### 7.1 General Handshake Semantics

All action-oriented blocks (`CLEAR`, `DRAW_TRIANGLE`, `DISPATCH_SIMD`) follow a common control pattern:

* The command processor asserts a start condition when a command enters the EXECUTE phase.

* The target block begins execution and may take multiple cycles to complete.

* The target block asserts a done signal when execution is complete.

* The command processor does not issue or execute subsequent commands until `done` is asserted.

* This start/done handshake enforces deterministic execution and preserves strict command ordering.

### 7.2 Stateful Command Behavior

State update commands (`SET_COLOR`, `SET_VIEWPORT`, `SET_FRAMEBUFFER`) do not use start/done handshakes.

* State updates are applied synchronously by the command processor.

* These commands complete in a single cycle during the EXECUTE phase.

* No backpressure or completion signaling is required.

### 7.3 CLEAR Command Interface

The CLEAR command interacts with the framebuffer controller as follows:

* The command processor asserts a clear start condition.

* The framebuffer controller uses current state (framebuffer address, viewport, color) to perform memory writes.

* The framebuffer controller asserts a clear done signal when all writes are complete.

### 7.4 DRAW_TRIANGLE Command Interface

The DRAW_TRIANGLE command interacts with the rasterizer:

* Vertex data is provided by the command processor, either buffered or streamed.

* The command processor asserts a raster start condition after payload delivery.

* The rasterizer consumes vertex data and current rendering state.

* The rasterizer asserts a raster done signal when triangle rasterization completes.

### 7.5 DISPATCH_SIMD Command Interface

The DISPATCH_SIMD command interacts with the SIMD compute core:

* The command processor provides an operation selector, element count, and input data.

* Data may be buffered or streamed to the SIMD core.

* The command processor asserts a SIMD start condition.

* The SIMD core processes all elements and asserts a SIMD done signal upon completion.

### 7.6 Design Invariants

* Only one action command may be active at a time.

* Start signals are only asserted in the EXECUTE phase.

* Done signals are required for all multi-cycle commands.

* State registers are stable throughout action command execution.

## 8. Command Definitions

### 8.1 SET_COLOR

**Purpose:** Update the current drawing color used by subsequent graphics commands.

**Opcode:** `0x10` (for clean separation from action ops)

**Payload:**

* Fixed-size payload (1 word)
* Contains color components (e.g., R, G, B)

  | Word Bits | Description |
  |-----------|-------------|
  |  [31:24]  |      R      |
  |  [23:16]  |      G      |
  |  [15:8]   |      B      |
  |  [7:0]    |  Reserved   |

**Notes:**

* Payload is fully consumed by the command processor
* Color is stored in internal state registers

---

### 8.2 SET_VIEWPORT

**Purpose:** Define the active rendering viewport in framebuffer coordinates.

**Opcode:** `0x11`

**Payload:**

* Fixed-size payload (4 words)
* Viewport bounds specified as:

  |  Word  | Description |
  |--------|-------------|
  |   0    |    x_min    |
  |   1    |    y_min    |
  |   2    |    x_max    |
  |   3    |    y_max    |

**Notes:**

* Coordinates are absolute framebuffer coordinates
* Payload is consumed locally and stored as state

---

### 8.3 SET_FRAMEBUFFER

**Purpose:** Set the base address of the framebuffer in external memory.

**Opcode:** `0x12`

**Payload:**

* Fixed-size payload (1 word)
* Contains framebuffer base address

**Notes:**

* Affects CLEAR and DRAW commands
* Address is stored in internal state registers

---

### 8.4 CLEAR

**Purpose:** Clear the active framebuffer region defined by the current viewport.

**Opcode:** `0x01`

**Payload:** 
* No payload (payload length = 0)

**Behavior:**

* Uses current color state
* Uses current viewport state
* Multi-cycle operation

---

### 8.5 DRAW_TRIANGLE

**Purpose:** Rasterize a single triangle using the current graphics state.

**Opcode:** `0x02`

**Payload:** 
* Fixed-size payload (6 words)
* Contains three vertices in screen space:

  | Word Index | Description |
  |------------|-------------|
  |     0      |     x0      |
  |     1      |     y0      |
  |     2      |     x1      |
  |     3      |     y1      |
  |     4      |     x2      |
  |     5      |     y2      |

**Coordinate Format:**

* Coordinates are integer screen-space (framebuffer) coordinates
* Each coordinate is provided as a 32-bit word
* Lower bits are used with upper bits are ignored in v1
* No fixed-point or floating-point support in v1

**Behavior:**

* The command processor consumes and buffers all payload words before execution
* The rasterizer is triggered only after the full payload has been received
* Color, viewport, and framebuffer are taken from current state
* The command completes when the rasterizer asserts `raster_done`

**Notes:**

* The payload format is fixed-size and deterministic in v1
* This format is intentionally simple to reduce hardware and software complexity
* Future versions may introduce packed formats, depth values, or per-vertex attributes

---

### 8.6 DISPATCH_SIMD

**Purpose:** Execute a SIMD compute operation on a set of input data.

**Payload:**

* Variable-length payload
* Contains:

  1. Operation selector (identifies fixed SIMD operation)
  2. Element count
  3. Input data elements

**Notes:**

* SIMD width and grouping are internal implementation details
* Payload data is streamed to the SIMD core
* Command completes when SIMD core signals `done`

## 9. Design Rationale

Key architectural decisions in v1:

* All state updates are ordered via FIFO commands
* No memory pointers in command payloads (v1)
* Payload lengths expressed in words
* Dispatcher execution model for simplicity and determinism

These choices reduce complexity while maintaining extensibility for future versions.

## 10. Future Extensions

Potential enhancements include:

* Non-blocking commands
* DMA-based payloads
* Z-buffer and depth testing
* Per-command flags
* Programmable shader-like stages
