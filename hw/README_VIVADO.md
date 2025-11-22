# Vivado Testing Guide - Systolic-Quant Integrated Design

## Quick Start

### Prerequisites
1. **Xilinx Vivado** installed (2019.2 or later recommended)
2. Source Vivado settings:
   ```bash
   source /tools/Xilinx/Vivado/<version>/settings64.sh
   ```

### Running Tests

```bash
cd hw

# Run simulation only (batch mode)
./run_vivado.sh sim

# Run simulation with GUI (view waveforms)
./run_vivado.sh sim-gui

# Run synthesis only
./run_vivado.sh synth

# Run both simulation and synthesis
./run_vivado.sh both

# Clean all generated files
./run_vivado.sh clean
```

---

## Available Options

| Command | Description |
|---------|-------------|
| `./run_vivado.sh sim` | Run behavioral simulation in batch mode |
| `./run_vivado.sh sim-gui` | Launch Vivado GUI for simulation |
| `./run_vivado.sh synth` | Run synthesis in batch mode |
| `./run_vivado.sh synth-gui` | Launch Vivado GUI for synthesis |
| `./run_vivado.sh impl` | Run implementation (place & route) in batch mode |
| `./run_vivado.sh impl-gui` | Launch Vivado GUI for implementation |
| `./run_vivado.sh both` | Run simulation then synthesis |
| `./run_vivado.sh full` | Run complete flow: sim → synth → impl |
| `./run_vivado.sh clean` | Remove all generated files |
| `./run_vivado.sh help` | Show help message |

---

## Detailed Workflows

### 1. Simulation Workflow

#### Batch Mode (No GUI)
```bash
./run_vivado.sh sim
```

**What it does:**
- Creates Vivado project in `scripts/vivado_sim/`
- Adds all RTL sources in correct dependency order
- Runs testbench (`systolic_quant_tb.sv`)
- Generates simulation log

**Output Files:**
- `vivado_sim.log` - Simulation log with test results
- `vivado_sim.jou` - Vivado journal file
- `scripts/vivado_sim/` - Project directory

**Expected Test Output:**
```
==========================================
Systolic-Quant Integrated Testbench
==========================================

Test 1: Simple 4x4 Matrix Multiply (Single Pass)
Test 2: Multi-Pass Accumulation (Simulating Tiled MatMul)
Test 3: Quantization with Scaling
Test 4: Signed Arithmetic

==========================================
All Tests Completed Successfully!
==========================================
```

#### GUI Mode (View Waveforms)
```bash
./run_vivado.sh sim-gui
```

**What it does:**
- Opens Vivado GUI
- Runs simulation automatically
- Allows you to add signals and view waveforms

**To view signals:**
1. In Vivado GUI, go to "Scope" panel
2. Navigate to `systolic_quant_tb` → `dut`
3. Right-click on signals → "Add to Wave Window"
4. Click "Restart" then "Run All" to see waveforms

**Recommended signals to view:**
- `a_in[*]`, `b_in[*]` - Inputs
- `systolic_out[*][*]` - Systolic array outputs
- `accum_out[*][*]` - Accumulated values
- `quant_out[*][*]` - Final quantized outputs
- `systolic_valid`, `quant_valid` - Control signals

---

### 2. Synthesis Workflow

#### Batch Mode
```bash
./run_vivado.sh synth
```

**What it does:**
- Creates synthesis project in `scripts/vivado_synth/`
- Synthesizes the integrated design
- Generates resource utilization and timing reports

**Output Files:**
- `vivado_synth.log` - Synthesis log
- `scripts/vivado_synth/utilization.rpt` - Resource usage
- `scripts/vivado_synth/timing_summary.rpt` - Timing analysis
- `scripts/vivado_synth/power.rpt` - Power estimation
- `scripts/vivado_synth/drc.rpt` - Design rule check

**Key Metrics to Check:**

1. **Resource Utilization:**
   ```bash
   grep -A 20 "Slice Logic Distribution" scripts/vivado_synth/utilization.rpt
   ```

2. **Timing:**
   ```bash
   grep -A 10 "Design Timing Summary" scripts/vivado_synth/timing_summary.rpt
   ```

3. **Power:**
   ```bash
   grep -A 10 "Summary" scripts/vivado_synth/power.rpt
   ```

#### GUI Mode
```bash
./run_vivado.sh synth-gui
```

**What it does:**
- Opens Vivado GUI with synthesis project
- Allows interactive exploration of synthesis results

**Useful Views in GUI:**
- **Schematic:** See synthesized netlist
- **Reports → Utilization:** Resource breakdown by module
- **Reports → Timing:** Critical path analysis
- **Power:** Power consumption breakdown

---

## File Structure

```
hw/
├── run_vivado.sh                 # Main automation script
├── scripts/
│   ├── vivado_sim.tcl            # Simulation TCL script
│   ├── vivado_synth.tcl          # Synthesis TCL script
│   ├── vivado_sim/               # (Generated) Simulation project
│   └── vivado_synth/             # (Generated) Synthesis project
├── src/
│   ├── pe.sv                     # Processing element
│   ├── systolic_mac.sv           # Systolic array core
│   ├── systolic_top.sv           # Systolic wrapper
│   ├── accumulator_bank.sv       # Accumulator module
│   ├── quant.sv                  # Requantization unit
│   └── systolic_quant_integrated.sv  # Top-level integration
├── tb/
│   └── systolic_quant_tb.sv      # Testbench
├── vivado_sim.log                # (Generated) Simulation log
├── vivado_synth.log              # (Generated) Synthesis log
└── README_VIVADO.md              # This file
```

---

## Customization

### Change Target FPGA

Edit `scripts/vivado_synth.tcl`:

```tcl
# Line 15: Change this to your target device
set fpga_part "xc7z020clg400-1"   # Default: Zynq-7000

# Other common targets:
# set fpga_part "xc7a100tcsg324-1"       # Artix-7
# set fpga_part "xczu9eg-ffvb1156-2-e"   # Zynq UltraScale+
# set fpga_part "xc7k325tffg900-2"       # Kintex-7
```

### Modify Simulation Runtime

Edit `scripts/vivado_sim.tcl`:

```tcl
# Line 70: Change simulation runtime
set_property -name {xsim.simulate.runtime} -value {500us} -objects [get_filesets sim_1]

# Or in the script itself:
run 500us  # Change to desired time
```

### Add Timing Constraints

Create `constraints/systolic_quant.xdc`:

```tcl
# Clock constraint
create_clock -period 10.0 -name clk [get_ports clk]

# Input/Output delays
set_input_delay -clock clk 2.0 [get_ports {a_in[*] b_in[*]}]
set_output_delay -clock clk 2.0 [get_ports {quant_out[*]}]
```

Then uncomment in `vivado_synth.tcl` (lines 49-53):

```tcl
if {[file exists "${constraint_dir}/systolic_quant.xdc"]} {
    add_files -fileset constrs_1 "${constraint_dir}/systolic_quant.xdc"
    puts "  Added timing constraints"
}
```

---

## Troubleshooting

### Problem: "Vivado not found in PATH"

**Solution:**
```bash
source /tools/Xilinx/Vivado/2022.1/settings64.sh
# Or wherever your Vivado is installed
```

### Problem: Simulation fails with elaboration errors

**Check:**
1. All source files are present in `src/` directory
2. File types are correct (`.sv` for SystemVerilog)
3. Module names match file names
4. No syntax errors in RTL

**Debug:**
```bash
# Check vivado_sim.log for details
cat vivado_sim.log | grep -i error
```

### Problem: Synthesis fails

**Common causes:**
1. **Unsupported SystemVerilog constructs** - Some SV features not synthesizable
2. **Combinational loops** - Check for feedback without registers
3. **Inferred latches** - Incomplete case/if statements

**Debug:**
```bash
# Check synthesis log
cat vivado_synth.log | grep -i "error\|warning"

# Look for critical warnings
grep -i "critical warning" vivado_synth.log
```

### Problem: Timing not met

**Solutions:**
1. **Add pipeline stages** - Break long combinational paths
2. **Reduce clock frequency** - Increase period in constraints
3. **Use faster speed grade** - Change FPGA part to `-2` or `-3`

**Analysis:**
```bash
# Find critical path
grep -A 20 "Worst Negative Slack" scripts/vivado_synth/timing_summary.rpt
```

---

## Performance Expectations

### Simulation
- **Runtime:** ~1-2 minutes (batch mode)
- **Tests:** 4 test cases covering different scenarios
- **Coverage:** Matrix multiply, accumulation, quantization, signed arithmetic

### Synthesis (Zynq-7000 XC7Z020)

Expected resource utilization:

| Resource | Usage | Available | Utilization |
|----------|-------|-----------|-------------|
| LUTs | ~2,500 | 53,200 | ~5% |
| FFs | ~2,000 | 106,400 | ~2% |
| DSPs | 16-32 | 220 | ~7-15% |
| BRAMs | 0-2 | 140 | ~0-1% |

**Estimated Fmax:** 200-300 MHz (depends on FPGA and placement)

---

## Next Steps After Verification

### 1. If Simulation Passes:
- ✅ RTL is functionally correct
- ✅ Ready for synthesis

### 2. If Synthesis Passes:
- ✅ Design is synthesizable
- ✅ Resource usage is reasonable
- → Run implementation to get accurate timing

### 3. Run Implementation:

#### Batch Mode (Automated)
```bash
./run_vivado.sh impl
```

**What it does:**
- Opens the synthesis project
- Runs place & route (implementation)
- Generates detailed timing and utilization reports
- Shows timing closure status (WNS/WHS)

**Output Files:**
- `vivado_impl.log` - Implementation log
- `vivado_synth/impl_timing_summary.rpt` - Final timing analysis
- `vivado_synth/impl_utilization.rpt` - Post-implementation resource usage
- `vivado_synth/impl_power.rpt` - Accurate power estimation
- `vivado_synth/impl_timing_detailed.rpt` - Detailed timing paths

**Check Timing:**
```bash
grep -A 5 "Timing Closure Check" vivado_impl.log
```

If **WNS ≥ 0** and **WHS ≥ 0**: ✅ Timing met - Ready for bitstream!
If **WNS < 0**: ❌ Setup timing failed - Reduce clock frequency or add pipeline stages
If **WHS < 0**: ❌ Hold timing failed - Check design for issues

#### GUI Mode (Interactive)
```bash
./run_vivado.sh impl-gui
```

Allows you to:
- View placed and routed design visually
- Analyze critical paths interactively
- Explore resource placement on die
- Run custom optimization strategies

### 4. Generate Bitstream (for FPGA):

After successful implementation with timing closure:

```bash
cd hw/scripts
vivado -mode tcl
```

Then in Vivado TCL console:
```tcl
open_project ./vivado_synth/systolic_quant_synth.xpr
open_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

Bitstream will be generated at:
`vivado_synth/systolic_quant_synth.runs/impl_1/systolic_quant_integrated.bit`

### 5. Complete Flow (Automated):

Run everything in one command:
```bash
./run_vivado.sh full
```

This will execute:
1. Simulation → Verify functional correctness
2. Synthesis → Check resource usage
3. Implementation → Verify timing closure

---

## Advanced Usage

### Custom TCL Commands

You can modify the TCL scripts or run custom commands:

```bash
# Run custom TCL script
vivado -mode batch -source my_custom.tcl

# Interactive TCL mode
vivado -mode tcl

# Then in Vivado TCL console:
source scripts/vivado_sim.tcl
```

### Scripted Parameter Sweep

Test different configurations:

```bash
# Edit systolic_quant_integrated.sv parameters
# Then re-run synthesis

for SIZE in 4 8 16; do
    # Modify ARRAY_SIZE parameter in source
    ./run_vivado.sh synth
    # Collect results
done
```

### Parallel Runs

```bash
# Run simulation and synthesis in parallel
./run_vivado.sh sim &
./run_vivado.sh synth &
wait
```

---

## Contact and Support

For issues or questions:
- Check `vivado_sim.log` and `vivado_synth.log` for detailed error messages
- Review Vivado documentation: https://www.xilinx.com/support/documentation.html
- Check project documentation in `docs/`

---

**Last Updated:** 2025-11-22
**Vivado Version Tested:** 2022.1
**Status:** ✅ Ready for testing
