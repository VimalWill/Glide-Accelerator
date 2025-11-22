####################################################################################
# Synthesis Design Constraints (SDC) for Systolic Array ASIC Implementation
# Project: Efficient Transformer Accelerator
# Module: systolic_top
# Target: ASIC synthesis flow
####################################################################################

# Clock Definition
# Adjust clock period based on target technology node
# Example: 500MHz = 2.0ns, 1GHz = 1.0ns
set CLOCK_PERIOD 2.0
set CLOCK_PORT clk

create_clock -name sys_clk -period $CLOCK_PERIOD [get_ports $CLOCK_PORT]

# Clock Uncertainty (includes jitter and skew)
# Adjust based on PLL specs and clock tree synthesis
set_clock_uncertainty 0.1 [get_clocks sys_clk]

# Clock Transition (slew rate)
set_clock_transition 0.05 [get_clocks sys_clk]

# Clock Latency (source and network)
# Source latency: delay from clock source to clock tree root
# Network latency: delay from clock tree root to registers
set_clock_latency -source 0.3 [get_clocks sys_clk]
set_clock_latency 0.2 [get_clocks sys_clk]

####################################################################################
# Input/Output Delays
####################################################################################

# Input delay: Time before clock edge when input data is stable
# Accounts for external device's Tco + board trace delay
set INPUT_DELAY 0.4
set_input_delay -clock sys_clk -max $INPUT_DELAY [get_ports a_in*]
set_input_delay -clock sys_clk -max $INPUT_DELAY [get_ports b_in*]
set_input_delay -clock sys_clk -max 0.3 [get_ports reset]
set_input_delay -clock sys_clk -max 0.3 [get_ports enable]

# Minimum input delay for hold analysis
set_input_delay -clock sys_clk -min 0.1 [get_ports a_in*]
set_input_delay -clock sys_clk -min 0.1 [get_ports b_in*]
set_input_delay -clock sys_clk -min 0.1 [get_ports reset]
set_input_delay -clock sys_clk -min 0.1 [get_ports enable]

# Output delay: Time needed for external device setup after clock edge
# Accounts for board trace delay + external device setup time
set OUTPUT_DELAY 0.4
set_output_delay -clock sys_clk -max $OUTPUT_DELAY [get_ports c_out*]
set_output_delay -clock sys_clk -min 0.1 [get_ports c_out*]

####################################################################################
# Environmental Constraints
####################################################################################

# Operating conditions - adjust based on technology library
# set_operating_conditions -max <worst_corner> -min <best_corner>
# Typical corners: worst (SS), typical (TT), best (FF)

# Temperature and voltage ranges
# set_temperature <value>
# set_voltage <value>

####################################################################################
# Load and Drive Strength
####################################################################################

# Input drive strength (from external drivers)
# Adjust based on actual input buffer strength
set_driving_cell -lib_cell <BUFFER_CELL> -library <LIB_NAME> [all_inputs]

# Output load capacitance (external load)
# Adjust based on actual PCB loading and fanout
set_load -pin_load 0.05 [all_outputs]

####################################################################################
# False Paths and Multicycle Paths
####################################################################################

# Asynchronous reset path (if async reset is used)
# set_false_path -from [get_ports reset]

# If reset is synchronous, set multicycle for reset paths
set_multicycle_path -setup 2 -from [get_ports reset]
set_multicycle_path -hold 1 -from [get_ports reset]

# Clock enable paths (if enable is quasi-static)
# Uncomment if enable changes infrequently
# set_false_path -from [get_ports enable]

####################################################################################
# Design Rules
####################################################################################

# Maximum transition time (slew rate) on nets
set_max_transition 0.15 [current_design]

# Maximum fanout
set_max_fanout 16 [current_design]

# Maximum capacitance
set_max_capacitance 0.1 [current_design]

####################################################################################
# Area Constraints (optional)
####################################################################################

# Maximum area constraint - let tool optimize
# set_max_area <value>

####################################################################################
# Power Optimization
####################################################################################

# Clock gating enable - synthesis tool should insert clock gates
# set_clock_gating_style -sequential_cell <cell_type> -control_point before -control_signal <signal>

# Dynamic power optimization
set_dynamic_optimization true

####################################################################################
# Special Constraints for Systolic Array
####################################################################################

# The systolic array has pipelined datapath
# Ensure proper timing through the PE chain

# All PE instances should have balanced delays
set_balance_registers true

# Group related logic for better placement
set PE_INSTANCES [get_cells -hierarchical -filter {ref_name =~ pe}]

# Optional: set dont_touch on critical PE instances to preserve structure
# set_dont_touch $PE_INSTANCES

# For better QoR, allow retiming across PE boundaries
set_optimize_registers true -design systolic_top

####################################################################################
# Compile Directives (Synthesis tool specific)
####################################################################################

# These are examples and may vary by tool (Synopsys DC, Cadence Genus, etc.)

# set_fix_hold [get_clocks sys_clk]
# set_dont_use [get_lib_cells <cells_to_avoid>]

# Compile strategy
# compile_ultra -gate_clock -no_autoungroup

####################################################################################
# Notes for ASIC Implementation:
####################################################################################
# 1. Adjust CLOCK_PERIOD based on target frequency and technology node
# 2. Update library references and cell names based on actual PDK
# 3. Set appropriate operating corners (PVT variations)
# 4. Consider adding constraints for:
#    - IR drop analysis
#    - EM (Electromigration) rules
#    - DFT (scan chain timing if implemented)
# 5. For advanced nodes (<= 28nm):
#    - Add On-Chip Variation (OCV) derates
#    - Consider multi-mode multi-corner (MMMC) analysis
# 6. Clock domain crossing (CDC) analysis if multiple clocks exist
####################################################################################
