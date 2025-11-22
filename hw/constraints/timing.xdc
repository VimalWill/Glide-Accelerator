# Timing Constraints for Systolic-Quant Integrated Design
# Target: ZCU104 (Zynq UltraScale+ MPSoC)
# Module: systolic_quant_integrated

#==============================================================================
# Clock Constraints
#==============================================================================

# Primary clock constraint
# ZCU104 can support high frequencies - starting with 200 MHz (5.0 ns period)
# Adjust based on your requirements and timing closure results
create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]

# Clock uncertainty (accounts for jitter, skew)
set_clock_uncertainty -setup 0.200 [get_clocks clk]
set_clock_uncertainty -hold 0.100 [get_clocks clk]

#==============================================================================
# Input Delay Constraints
#==============================================================================

# Input delays relative to clock
# Assume inputs arrive from external logic with 1.0ns delay
set input_delay_value 1.0

# Data inputs (4x4 array inputs)
set_input_delay -clock clk -max $input_delay_value [get_ports {a_in[*]}]
set_input_delay -clock clk -max $input_delay_value [get_ports {b_in[*]}]

# Control signals
set_input_delay -clock clk -max $input_delay_value [get_ports enable]
set_input_delay -clock clk -max $input_delay_value [get_ports accum_clear]
set_input_delay -clock clk -max $input_delay_value [get_ports accum_enable]
set_input_delay -clock clk -max $input_delay_value [get_ports quant_enable]

# Quantization parameters
set_input_delay -clock clk -max $input_delay_value [get_ports {scale_factor[*]}]
set_input_delay -clock clk -max $input_delay_value [get_ports {shift_amount[*]}]

#==============================================================================
# Output Delay Constraints
#==============================================================================

# Output delays relative to clock
# Assume outputs must be stable 1.0ns before next clock edge at receiving logic
set output_delay_value 1.0

# Quantized outputs (4x4 array)
set_output_delay -clock clk -max $output_delay_value [get_ports {quant_out[*]}]

# Status/valid signals
set_output_delay -clock clk -max $output_delay_value [get_ports systolic_valid]
set_output_delay -clock clk -max $output_delay_value [get_ports accum_overflow]
set_output_delay -clock clk -max $output_delay_value [get_ports quant_valid]

#==============================================================================
# False Paths (Asynchronous signals)
#==============================================================================

# Reset is asynchronous - disable timing checks
set_false_path -from [get_ports reset]

# Overflow flag is status only - can relax timing if needed
# (Uncomment if timing fails and overflow is not critical)
# set_false_path -to [get_ports accum_overflow]

#==============================================================================
# Multicycle Paths (if needed)
#==============================================================================

# If certain paths need multiple cycles to resolve, define them here
# Example: Accumulator might take multiple cycles
# set_multicycle_path -setup 2 -from [get_cells -hier -filter {NAME =~ *accum_regs*}]

#==============================================================================
# Case Analysis (for mode-specific optimization)
#==============================================================================

# If certain control signals are static during operation, set them here
# Example: If scale_factor doesn't change often
# set_case_analysis 0 [get_ports {scale_factor[31]}]

#==============================================================================
# Design Rule Checks
#==============================================================================

# Maximum fanout limit
set_max_fanout 20 [current_design]

# Maximum transition time (slew rate)
set_max_transition 0.5 [current_design]

#==============================================================================
# Power Optimization (for UltraScale+)
#==============================================================================

# Enable automatic clock gating (UltraScale+ feature)
# This will reduce dynamic power consumption
set_property CLOCK_GATING TRUE [current_design]

#==============================================================================
# Notes and Guidelines
#==============================================================================

# Clock Period Options:
#   Conservative: 10.0 ns (100 MHz)  - Good for first implementation
#   Moderate:     5.0 ns  (200 MHz)  - Typical for UltraScale+
#   Aggressive:   3.0 ns  (333 MHz)  - May require pipeline optimization
#   Very Fast:    2.0 ns  (500 MHz)  - Requires careful optimization

# To change target frequency:
#   1. Modify the create_clock -period value above
#   2. Re-run synthesis: ./run_vivado.sh synth
#   3. Check timing_summary.rpt for WNS (Worst Negative Slack)
#   4. If WNS < 0, timing failed - reduce frequency or add pipeline stages

# For implementation (place & route):
#   In Vivado GUI or TCL:
#     launch_runs impl_1
#     wait_on_run impl_1
#     open_run impl_1
#     report_timing_summary -file timing_final.rpt
