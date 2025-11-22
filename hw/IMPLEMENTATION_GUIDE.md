# Implementation Guide - ZCU104 Timing Closure

## Overview

This guide covers running implementation (place & route) for the systolic-quant integrated design on the ZCU104 board. Implementation is the step after synthesis where:
1. Logic is **placed** on specific FPGA resources
2. Connections are **routed** between components
3. **Accurate timing** is analyzed based on actual wire delays
4. **Final resource** usage is determined

---

## Prerequisites

✅ **Synthesis must complete first**
```bash
cd hw
./run_vivado.sh synth
```

If synthesis hasn't been run, the implementation script will exit with an error.

---

## Quick Start

### Option 1: Batch Mode (Recommended for first run)
```bash
./run_vivado.sh impl
```

This will:
- Run place & route automatically
- Generate all timing and utilization reports
- Display timing closure status
- Take ~5-15 minutes depending on your machine

### Option 2: Complete Flow
```bash
./run_vivado.sh full
```

Runs: Simulation → Synthesis → Implementation in one command

### Option 3: GUI Mode (for analysis)
```bash
./run_vivado.sh impl-gui
```

Opens Vivado GUI where you can:
- View the placed design visually
- Analyze critical timing paths interactively
- Explore different optimization strategies

---

## Understanding Timing Constraints

The design is currently configured with:

### Clock Frequency: 200 MHz (5.0 ns period)

**File:** `constraints/timing.xdc` (line 12)
```tcl
create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]
```

### Key Timing Metrics

**WNS (Worst Negative Slack) - Setup Timing:**
- Measures if data arrives **before** the next clock edge
- **WNS ≥ 0**: ✅ Timing met - Design works at target frequency
- **WNS < 0**: ❌ Timing failed - Data too slow, won't work reliably
- Example: WNS = -0.5 ns means you're 0.5 ns too slow

**WHS (Worst Hold Slack) - Hold Timing:**
- Ensures data is **stable long enough** after clock edge
- **WHS ≥ 0**: ✅ No hold violations
- **WHS < 0**: ❌ Hold violation - Data changes too quickly
- Hold failures usually indicate design errors, not just slow paths

### Adjusting Clock Frequency

If timing fails, you can reduce the clock frequency:

**Edit:** `hw/constraints/timing.xdc`

```tcl
# Conservative: 100 MHz (10.0 ns)
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# Moderate: 200 MHz (5.0 ns) - Current setting
create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]

# Aggressive: 333 MHz (3.0 ns)
create_clock -period 3.000 -name clk -waveform {0.000 1.500} [get_ports clk]

# Very Fast: 500 MHz (2.0 ns) - May be challenging
create_clock -period 2.000 -name clk -waveform {0.000 1.000} [get_ports clk]
```

After changing, re-run synthesis and implementation:
```bash
./run_vivado.sh clean
./run_vivado.sh synth
./run_vivado.sh impl
```

---

## Generated Reports

All reports are saved in: `hw/scripts/vivado_synth/impl_*.rpt`

### Critical Reports to Check

#### 1. Timing Summary
**File:** `impl_timing_summary.rpt`

**Check:**
```bash
grep -A 10 "Design Timing Summary" hw/scripts/vivado_synth/impl_timing_summary.rpt
```

**Look for:**
```
WNS(ns)      TNS(ns)  TNS Failing Endpoints
-------      -------  ---------------------
  0.123         0.0                      0    ← Good! Positive slack
```

**Or:**
```
WNS(ns)      TNS(ns)  TNS Failing Endpoints
-------      -------  ---------------------
 -0.456       -23.4                    142    ← Bad! Negative slack, 142 paths failing
```

#### 2. Detailed Timing Paths
**File:** `impl_timing_detailed.rpt`

Shows the 10 slowest paths in the design. Use this to identify bottlenecks:

```bash
head -100 hw/scripts/vivado_synth/impl_timing_detailed.rpt
```

**Example critical path:**
```
Path 1:
  Start: systolic_mac/pe_array[0][0]/mult_result_reg[15]/C
  End:   accumulator/accum_regs[0][0][31]/D
  Slack: -0.234 ns  ← This path is too slow!

  Logic delay:   2.3 ns
  Routing delay: 2.9 ns  ← High routing delay indicates long wires
  Total:         5.2 ns  ← Exceeds 5.0 ns budget
```

#### 3. Utilization Report
**File:** `impl_utilization.rpt`

Post-implementation resource usage (more accurate than synthesis):

```bash
grep -A 20 "Slice Logic" hw/scripts/vivado_synth/impl_utilization.rpt
```

#### 4. Power Report
**File:** `impl_power.rpt`

Accurate power consumption after place & route:

```bash
grep -A 15 "Total On-Chip Power" hw/scripts/vivado_synth/impl_power.rpt
```

---

## Timing Closure Strategies

### If WNS < 0 (Setup Timing Failed)

#### Strategy 1: Reduce Clock Frequency (Easiest)
- Edit `constraints/timing.xdc`
- Increase period (e.g., 5.0 → 10.0 ns for 200 → 100 MHz)
- Re-run synthesis and implementation

#### Strategy 2: Try Different Implementation Strategy
Edit `scripts/vivado_impl.tcl` (line 29):

```tcl
# Current:
set_property strategy Performance_Explore [get_runs impl_1]

# Alternatives to try:
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property strategy Performance_ExploreWithRemap [get_runs impl_1]
```

Then re-run: `./run_vivado.sh impl`

#### Strategy 3: Add Pipeline Stages (Best long-term)
If a specific path is consistently failing:
1. Identify the critical path from `impl_timing_detailed.rpt`
2. Add register stages in the RTL to break up long combinational paths
3. Example: Add pipeline stage in accumulator or requantization module

#### Strategy 4: Use Multicycle Paths
If certain operations genuinely take multiple cycles:

Edit `constraints/timing.xdc`:
```tcl
# Allow accumulator 2 cycles instead of 1
set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ *accum_regs*}]
set_multicycle_path -hold 1 -from [get_cells -hier -filter {NAME =~ *accum_regs*}]
```

### If WHS < 0 (Hold Timing Failed)

Hold failures are usually more serious and indicate:
1. **Logic too fast** - Data arrives too early at next register
2. **Clock skew** - Unbalanced clock distribution
3. **Design error** - Combinational loops or improper constraints

**Solutions:**
- Check for combinational loops: Look for "combinational loop" warnings
- Verify reset is properly constrained as false path
- Add input/output delays if interfacing with external logic
- Review clock constraints for errors

---

## Expected Results for ZCU104

### Target Frequency: 200 MHz (5.0 ns)

**Estimated achievable Fmax:** 200-350 MHz depending on placement

**Expected Timing (at 200 MHz):**
- WNS: +0.5 to +2.0 ns (positive slack - good!)
- WHS: +0.05 to +0.2 ns (positive - good!)

**If timing fails at 200 MHz:**
- Try 150 MHz (6.67 ns): Should easily close
- Try 100 MHz (10.0 ns): Very conservative, guaranteed to work

### Resource Utilization (Post-Implementation)

Expected similar to synthesis, slightly higher:

| Resource | Usage | Available | Utilization |
|----------|-------|-----------|-------------|
| LUTs | ~5,500 | 230,400 | ~2.4% |
| Registers | ~3,500 | 460,800 | ~0.8% |
| DSPs | 64 | 1,728 | 3.7% |

### Power Consumption

**Estimated Total Power:** 0.5 - 1.5 W
- Static power: ~0.3 W (leakage)
- Dynamic power: ~0.2-1.2 W (depends on clock freq and activity)

Lower power if:
- Clock gating is active (enabled in constraints)
- Lower operating frequency
- Lower toggle rates on signals

---

## Troubleshooting

### Error: "Synthesis project not found"
```bash
# Run synthesis first:
./run_vivado.sh synth
# Then run implementation:
./run_vivado.sh impl
```

### Implementation takes too long (>30 minutes)
- Normal for first run with aggressive timing constraints
- Try reducing clock frequency to 100 MHz for faster convergence
- Use `impl-gui` to monitor progress

### "CRITICAL WARNING: Timing constraints are not met"
This is actually OK - it just means WNS < 0. Check the detailed reports:
```bash
grep -A 5 "Timing Closure Check" vivado_impl.log
```

### Multiple DRC or Methodology warnings
Some warnings are benign. Focus on:
- **TIMING** warnings - Always address
- **NSTD** (non-standard I/O) - OK for internal modules
- **REQP** (required property) - Usually not critical for internal design

### Want to see visual layout
```bash
./run_vivado.sh impl-gui
```
Then: Open Run → impl_1 → Layout → Device view

---

## Next Steps After Successful Implementation

### 1. Check Timing Closure
```bash
grep -A 5 "Timing Closure Check" vivado_impl.log
```

### 2. Review Resource Usage
```bash
cat hw/scripts/vivado_synth/impl_utilization.rpt
```

### 3. Analyze Power
```bash
grep -A 20 "Total On-Chip Power" hw/scripts/vivado_synth/impl_power.rpt
```

### 4. Generate Bitstream (if targeting FPGA)
```bash
cd hw/scripts
vivado -mode tcl
```

In Vivado TCL:
```tcl
open_project ./vivado_synth/systolic_quant_synth.xpr
open_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

Bitstream location:
```
hw/scripts/vivado_synth/systolic_quant_synth.runs/impl_1/systolic_quant_integrated.bit
```

### 5. For ASIC Flow
If targeting ASIC instead of FPGA:
- Use the RTL source files directly
- Apply `constraints/synthesis_asic.sdc` for timing constraints
- Feed to your ASIC synthesis tool (Design Compiler, Genus, etc.)

---

## Performance Tuning

### Maximize Performance (Fmax)
1. Use `Performance_ExplorePostRoutePhysOpt` strategy
2. Enable physical optimization:
   ```tcl
   set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
   ```
3. Add pipeline stages in critical paths

### Minimize Area
1. Use `Area_Explore` strategy
2. Enable logic trimming and aggressive merging
3. Share resources where possible

### Minimize Power
1. Enable clock gating (already set in constraints)
2. Reduce clock frequency to minimum needed
3. Use `Power_DefaultOpt` strategy

### Fastest Implementation Time
1. Use default strategy (no exploration)
2. Set lower clock frequency (easier to meet)
3. Disable post-route optimization

---

## Command Reference

```bash
# Run implementation
./run_vivado.sh impl

# Run implementation with GUI
./run_vivado.sh impl-gui

# Run complete flow (sim + synth + impl)
./run_vivado.sh full

# Clean everything and start fresh
./run_vivado.sh clean
./run_vivado.sh full

# Check timing results
grep "WNS" vivado_impl.log
grep -A 5 "Timing Closure Check" vivado_impl.log

# View all reports
ls -lh hw/scripts/vivado_synth/impl_*.rpt
```

---

**Last Updated:** 2025-11-22
**Target Board:** ZCU104 (xczu7ev-ffvc1156-2-e)
**Status:** ✅ Ready for implementation
