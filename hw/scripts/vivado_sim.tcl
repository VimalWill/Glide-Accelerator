####################################################################################
# Vivado Simulation TCL Script
# Project: 32x16 Systolic Array Accelerator
# Purpose: Run behavioral simulation of 32x16 systolic array with quantization
####################################################################################

# Set project variables
set project_name "systolic_32x16_sim"
set project_dir "./vivado_sim"
set top_module "systolic_32x16_tb"

# Source file paths (relative to hw directory)
set src_dir "../src"
set tb_dir "../tb"

puts "=========================================="
puts "Vivado Simulation Setup - 32x16 Array"
puts "=========================================="
puts "Project: $project_name"
puts "Top Module: $top_module"
puts ""

# Create project directory if it doesn't exist
file mkdir $project_dir

# Create new project
create_project $project_name $project_dir -force
set proj [current_project]

puts "Project created: $project_name"

# Set project properties
set_property target_language Verilog $proj
set_property simulator_language Mixed $proj
set_property default_lib work $proj

# Add source files in dependency order
puts "\nAdding source files..."

# Level 1: Processing Element
add_files -fileset sources_1 "${src_dir}/pe.sv"
puts "  Added: pe.sv"

# Level 2: Rectangular Systolic Array Core (32x16)
add_files -fileset sources_1 "${src_dir}/systolic_mac_rect.sv"
puts "  Added: systolic_mac_rect.sv"

# Level 3: Accumulator Bank (rectangular support)
add_files -fileset sources_1 "${src_dir}/accumulator_bank.sv"
puts "  Added: accumulator_bank.sv"

# Level 4: Quantization Module
add_files -fileset sources_1 "${src_dir}/quant.sv"
puts "  Added: quant.sv"

# Level 5: Shared Quantization Module
add_files -fileset sources_1 "${src_dir}/quant_shared.sv"
puts "  Added: quant_shared.sv"

# Level 6: 32x16 Integrated Top
add_files -fileset sources_1 "${src_dir}/systolic_quant_32x16.sv"
puts "  Added: systolic_quant_32x16.sv"

# Add testbench
add_files -fileset sim_1 "${tb_dir}/systolic_32x16_tb.sv"
puts "  Added: systolic_32x16_tb.sv (testbench)"

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set top module for simulation
set_property top $top_module [get_filesets sim_1]
set_property top_lib work [get_filesets sim_1]

puts "\nCompile order updated"

# Set simulation properties
set_property -name {xsim.simulate.runtime} -value {2ms} -objects [get_filesets sim_1]
set_property -name {xsim.elaborate.debug_level} -value {all} -objects [get_filesets sim_1]

# Enable SystemVerilog support
set_property file_type SystemVerilog [get_files *.sv]

puts "\n=========================================="
puts "Launching Simulation..."
puts "=========================================="

# Launch simulation
launch_simulation

# Run simulation
puts "\nRunning simulation for 2ms (testbench has 2ms timeout)..."
run all

puts "\n=========================================="
puts "Simulation Complete!"
puts "=========================================="
puts "\nTest Results:"
puts "  Check console output above for test status"
puts "  - Test 1: Outer Product [1x1] = 1"
puts "  - Test 2: Scaled Values [2x3] = 6"
puts "  - Test 3: Multi-Pass Accumulation = 8"
puts ""
puts "To view waveforms:"
puts "  1. Open Vivado GUI"
puts "  2. Go to simulation view"
puts "  3. Add signals to waveform viewer"
puts "  4. VCD file: systolic_32x16_tb.vcd"
puts ""
