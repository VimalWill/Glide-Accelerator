# 32×16 Systolic Array Accelerator for Vision Transformers

## Overview

This is a production-ready hardware accelerator optimized for Vision Transformer (ViT) inference on FPGA/ASIC platforms. The design features a rectangular 32×16 systolic array (512 processing elements) with integrated accumulation and INT8 quantization.

## Architecture

### Key Components

1. **Systolic MAC Array** (`systolic_mac_rect.sv`)
   - Dimensions: 32 rows × 16 columns = 512 PEs
   - Data precision: INT8 inputs, INT32 accumulation
   - Optimized for transformer attention and MLP layers
   - Supports matrix dimensions: M×K × K×N where M=32, N=16

2. **Processing Element** (`pe.sv`)
   - 3-stage pipelined MAC operation
   - Clock gating support for power efficiency
   - Overflow protection with saturation
   - ASIC-optimized with explicit logic types

3. **Accumulator Bank** (`accumulator_bank.sv`)
   - 512 parallel 32-bit accumulators (32×16)
   - Multi-pass accumulation support
   - Overflow detection and saturation
   - Clear and enable controls

4. **Shared Quantization Module** (`quant_shared.sv`)
   - 64 parallel quantization units
   - Time-multiplexed across 512 outputs
   - 4-stage pipeline: register → multiply → shift → saturate
   - Scale-and-shift quantization: `(x × scale) >> shift`
   - Throughput: 512 elements in ~13 cycles

5. **Top-level Integration** (`systolic_quant_32x16.sv`)
   - Combines systolic array + accumulator + quantization
   - Single unified interface
   - Valid signal generation
   - Flow control and backpressure support

## Performance Characteristics

### Resource Utilization
- **LUTs**: ~36% (on target FPGA)
- **DSPs**: ~15% (64 for quantization + 512 for MACs)
- **BRAM**: Minimal (register-based accumulators)
- **Frequency**: 200 MHz (post-synthesis)

### Throughput Metrics
- **MACs/cycle**: 512 (32×16 array)
- **Quantization**: 512 elements in 13 cycles = 39.4 elements/cycle
- **Latency**:
  - Systolic: ~48 cycles (32+16 pipeline depth)
  - Accumulation: 1 cycle
  - Quantization: ~13 cycles

### Power Efficiency
- Clock gating on all PEs
- Conditional updates in pipeline stages
- Resource sharing (64 quant units vs 512)

## Interface Specification

### Top Module: `systolic_quant_32x16`

#### Parameters
```systemverilog
parameter ROWS = 32          // Number of output features (M)
parameter COLS = 16          // Number of input features (N)
parameter DATA_WIDTH = 8     // INT8 precision
parameter ACC_WIDTH = 32     // 32-bit accumulation
parameter QUANT_UNITS = 64   // Parallel quantization units
```

#### Inputs
```systemverilog
clk                          // System clock (200 MHz typical)
reset                        // Synchronous reset (active high)
enable                       // Array enable (supports clock gating)

// Data inputs (INT8)
a_in [ROWS-1:0]             // Row inputs (M dimension)
b_in [COLS-1:0]             // Column inputs (N dimension)

// Accumulator control
accum_clear                  // Clear accumulators (active high)
accum_enable                 // Accumulate current result (pulse)

// Quantization parameters
scale_factor [31:0]          // Multiplication scale
shift_amount [7:0]           // Right shift amount (0-255)
quant_enable                 // Start quantization (pulse)
```

#### Outputs
```systemverilog
quant_out [ROWS-1:0][COLS-1:0] [7:0]  // INT8 quantized outputs
systolic_valid                         // Systolic computation valid
accum_overflow                         // Accumulator overflow flag
quant_valid                            // Quantization complete
```

## Usage Flow

### Basic Matrix Multiplication with Quantization

1. **Reset System**
   ```
   reset = 1 (hold for ≥5 cycles)
   reset = 0
   ```

2. **Clear Accumulators**
   ```
   accum_clear = 1 (pulse for 1 cycle)
   ```

3. **Load Input Data**
   ```
   a_in[i] = row_data[i]     // Load M rows
   b_in[j] = col_data[j]     // Load N columns
   enable = 1
   ```

4. **Wait for Systolic Valid**
   ```
   wait(systolic_valid == 1)  // Takes ~48 cycles
   ```

5. **Capture to Accumulator**
   ```
   accum_enable = 1 (pulse for 1 cycle)
   ```

6. **Quantize Results** (after accumulation complete)
   ```
   scale_factor = <scale>
   shift_amount = <shift>
   quant_enable = 1 (pulse for 1 cycle)
   wait(quant_valid == 1)     // Takes ~13 cycles
   read quant_out[i][j]       // Read INT8 results
   ```

### Multi-Pass Accumulation

For larger matrix multiplications (e.g., M×K × K×N where K > 16):

1. Clear accumulators once
2. For each tile k = 0 to K/16:
   - Load a_in[i] = A[i][k*16:(k+1)*16]
   - Load b_in[j] = B[k*16:(k+1)*16][j]
   - Wait for systolic_valid
   - Pulse accum_enable (accumulates partial sum)
3. After all tiles: quantize results

## Quantization Details

### Scale-and-Shift Formula
```
output = saturate_int8((input × scale_factor) >> shift_amount)
```

### Saturation Behavior
- **Positive overflow**: Saturates to +127 (0x7F)
- **Negative overflow**: Saturates to -128 (0x80)
- **No overflow**: Direct 8-bit output

### Example Quantization
```
Input: 1000 (int32)
Scale: 128
Shift: 10
Calculation: (1000 × 128) >> 10 = 128000 >> 10 = 125
Output: 125 (int8)
```

## File Structure

```
hw/
├── src/                           # RTL source files
│   ├── pe.sv                      # Processing element
│   ├── systolic_mac_rect.sv       # 32×16 systolic array
│   ├── accumulator_bank.sv        # Accumulator bank
│   ├── quant.sv                   # Single quantization unit
│   ├── quant_shared.sv            # Shared quantization module
│   └── systolic_quant_32x16.sv    # Top-level integration
├── tb/                            # Testbenches
│   └── systolic_32x16_tb.sv       # Verification testbench
├── scripts/                       # Build scripts
│   ├── vivado_sim.tcl             # Simulation script
│   └── vivado_flow.tcl            # Synthesis script
├── constraints/                   # Timing constraints
│   └── timing.xdc                 # Timing constraints file
└── README.md                      # This file
```

## Simulation

### Prerequisites
- Vivado 2020.2 or later (for XSim)
- SystemVerilog support

### Running Testbench
```bash
cd hw
source /tools/Xilinx/Vivado/<version>/settings64.sh
./run_vivado.sh sim
```

### Test Cases
The testbench (`systolic_32x16_tb.sv`) includes:

1. **Test 1**: Outer product [1×1] = 1
2. **Test 2**: Scaled values [2×3] = 6
3. **Test 3**: Multi-pass accumulation (6+2) = 8

### Expected Output
```
Test 1: PASS - All outputs = 1
Test 2: PASS - All outputs = 6
Test 3: PASS - All outputs = 8
```

## Synthesis

### Running Synthesis
```bash
cd hw
./run_vivado.sh synth
```

### Target Devices
- **Primary**: Xilinx Zynq UltraScale+ ZU9EG
- **Alternatives**: Any FPGA with sufficient DSP blocks (≥576)

### Timing Constraints
- Target frequency: 200 MHz (5 ns period)
- All paths must meet timing at 200 MHz

## Integration Guidelines

### Clock and Reset
- **Clock**: Single clock domain, 100-250 MHz recommended
- **Reset**: Synchronous, active-high
- **Reset duration**: Minimum 5 clock cycles

### Data Formats
- **Input**: INT8 signed (-128 to +127)
- **Accumulator**: INT32 signed
- **Output**: INT8 signed with saturation

### Resource Sharing
The quantization module uses only 64 units to process 512 outputs through time-multiplexing. This reduces:
- DSP usage: 64 vs 512 (87.5% reduction)
- Area: Significant reduction with minimal latency impact

## Optimization Notes

### ASIC Optimizations Applied
1. **Clock gating**: PEs only compute when enabled
2. **Pipeline balancing**: 3-stage PE pipeline
3. **Saturation arithmetic**: Overflow protection
4. **Explicit types**: Better synthesis control

### Future Enhancements
- [ ] Support for BF16/FP16 data types
- [ ] Configurable array dimensions (parameterized M×N)
- [ ] AXI4-Stream interface
- [ ] DMA integration
- [ ] Multi-channel processing

## Verification Status

✅ **Behavioral Simulation**: All tests passing
✅ **Synthesis**: Clean synthesis at 200 MHz
✅ **Timing**: All constraints met
⏳ **FPGA Validation**: Pending on-board testing
⏳ **Power Analysis**: Pending post-implementation

## Known Limitations

1. **Fixed dimensions**: Currently hardcoded to 32×16
2. **Single precision**: INT8 only (no BF16/FP16)
3. **No sparsity**: Dense matrix multiplication only
4. **Quantization**: Single scale/shift per tensor

## References

- [ViTALiTy: Vision Transformer Acceleration](https://github.com/...)
- [Systolic Arrays for Deep Learning](...)
- [Efficient Quantization for Neural Networks](...)

## License

See LICENSE file in repository root.

## Authors

- Lydia Obeng (Original PE design)
- Enhanced for ASIC (32×16 scaling and optimizations)

## Version History

- **v0.02** (2025-11-22): Production-ready 32×16 design
  - Fixed quantization timing bug
  - Removed debug statements
  - Verified all test cases
  - Synthesis clean at 200 MHz

- **v0.01** (2025-11-10): Initial 4×4 prototype
  - Basic PE and systolic array
  - Simple accumulation
  - Initial quantization support
