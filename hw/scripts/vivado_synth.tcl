####################################################################################
# Vivado Synthesis TCL Script
# Project: Efficient Transformer Accelerator
# Purpose: Synthesize systolic-quant integrated design for FPGA/ASIC
####################################################################################

# Set project variables
set project_name "systolic_quant_synth"
set project_dir "./vivado_synth"
set top_module "systolic_quant_32x16"

# FPGA part (change this to your target device)
# Examples:
#   Xilinx Zynq-7000: xc7z020clg400-1
#   Xilinx UltraScale+: xczu9eg-ffvb1156-2-e
#   Xilinx Artix-7: xc7a100tcsg324-1
#   ZCU104: xczu7ev-ffvc1156-2-e
set fpga_part "xczu7ev-ffvc1156-2-e"

# Source file paths
set src_dir "../src"
set constraint_dir "../constraints"

puts "=========================================="
puts "Vivado Synthesis Setup"
puts "=========================================="
puts "Project: $project_name"
puts "Top Module: $top_module"
puts "Target Device: $fpga_part"
puts ""

# Create project directory
file mkdir $project_dir

# Create new project
create_project $project_name $project_dir -part $fpga_part -force
set proj [current_project]

puts "Project created successfully"

# Set project properties
set_property target_language Verilog $proj
set_property default_lib work $proj

# Add source files
puts "\nAdding source files..."

add_files -fileset sources_1 [list \
    "${src_dir}/pe.sv" \
    "${src_dir}/systolic_mac.sv" \
    "${src_dir}/systolic_top.sv" \
    "${src_dir}/accumulator_bank.sv" \
    "${src_dir}/quant.sv" \
    "${src_dir}/systolic_quant_integrated.sv" \
    "${src_dir}/systolic_mac_rect.sv" \
    "${src_dir}/quant_shared.sv" \
    "${src_dir}/systolic_quant_32x16.sv" \
]

puts "  Added all RTL source files"

# Set file types
set_property file_type SystemVerilog [get_files *.sv]

# Update compile order
update_compile_order -fileset sources_1

# Set top module
set_property top $top_module [current_fileset]

puts "  Top module set: $top_module"

# Add constraints
if {[file exists "${constraint_dir}/timing.xdc"]} {
    add_files -fileset constrs_1 "${constraint_dir}/timing.xdc"
    puts "  Added timing constraints: timing.xdc"
} else {
    puts "  WARNING: No timing constraints found"
}

puts "\n=========================================="
puts "Running Synthesis..."
puts "=========================================="

# Synthesis settings
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE Default [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING false [get_runs synth_1]

# Run synthesis
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

puts "\n=========================================="
puts "Synthesis Complete!"
puts "=========================================="

# Open synthesized design
open_run synth_1

# Generate reports
puts "\nGenerating reports..."

# Utilization report
report_utilization -file ${project_dir}/utilization.rpt
puts "  Utilization report: utilization.rpt"

# Timing summary
report_timing_summary -file ${project_dir}/timing_summary.rpt
puts "  Timing summary: timing_summary.rpt"

# Power report
report_power -file ${project_dir}/power.rpt
puts "  Power report: power.rpt"

# DRC report
report_drc -file ${project_dir}/drc.rpt
puts "  DRC report: drc.rpt"

# Print summary to console
puts "\n=========================================="
puts "Resource Utilization Summary:"
puts "=========================================="
report_utilization -hierarchical

puts "\n=========================================="
puts "Timing Summary:"
puts "=========================================="
report_timing_summary

puts "\n=========================================="
puts "Synthesis Results:"
puts "=========================================="
puts "All reports saved to: $project_dir/"
puts "  - utilization.rpt"
puts "  - timing_summary.rpt"
puts "  - power.rpt"
puts "  - drc.rpt"
puts ""
puts "To implement the design, run:"
puts "  launch_runs impl_1"
puts "  wait_on_run impl_1"
puts ""
