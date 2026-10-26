# 32-Bit RV32I 5-Stage Pipelined RISC-V Processor Core

A fully verified 32-bit 5-stage pipelined RISC-V (RV32I ISA) processor core written in **SystemVerilog**. This core implements a classical Harvard architecture pipeline featuring hazard mitigation via a dedicated **Data Forwarding Unit** to sustain single-cycle instruction execution flow across data dependencies.

---

## 🏛️ Architecture Overview

The core implements a standard 5-stage pipeline architecture:

1. **Instruction Fetch (IF):** Increments Program Counter (PC + 4) and fetches 32-bit instruction words from synchronous instruction memory (`imem`).
2. **Instruction Decode (ID):** Decodes RV32I opcodes, extracts immediate values (`I-type`), and reads source registers (`rs1`, `rs2`) from the 32x32-bit register file.
3. **Execute (EX):** Performs ALU arithmetic/logic operations and dynamically resolves data hazards using register forwarding logic.
4. **Memory (MEM):** Handles data memory interface boundaries and passes execution/memory results to the writeback stage.
5. **Writeback (WB):** Writes computation results back to target destination registers (`rd`) in the register file.

### Data Hazard Resolution
To minimize pipeline stalls caused by Read-After-Write (RAW) data dependencies, a **Data Forwarding Unit** continuously monitors register write-enable signals and target register indices across the **EX/MEM** and **MEM/WB** pipeline registers. If an active source register matches a downstream destination register, operands are bypassed directly to the execution unit in real-time.

---

## 🛠️ Tech Stack & Tools

* **Hardware Description Language:** SystemVerilog (IEEE 1800)
* **Simulation Engine:** Icarus Verilog (`iverilog` -g2012)
* **Waveform Analysis:** GTKWave / Value Change Dump (`.vcd`)
* **Environment:** Executable on Linux / Termux (ARM64)

---

## 📂 Project Structure

```text
├── cpu_core.sv    # Top-level SystemVerilog core (Pipeline, Hazard Unit, ALU, Memory)
├── tb_cpu.sv      # SystemVerilog simulation testbench & trace logger
├── Makefile       # Automated compilation and execution script
└── README.md      # Architecture documentation
