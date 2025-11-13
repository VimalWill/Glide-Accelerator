################################################################################
# Vivado Non-GUI Synthesis and Implementation Flow
# For High-Frequency Requantization Module
################################################################################

# Configuration
set project_name "requant_project"
set top_module "quant_top"
set output_dir "./build"
set reports_dir "./reports"

# FPGA Part - ZCU104 Board
set fpga_part "xczu7ev-ffvc1156-2-e"

puts "==============================================="
puts "Starting Vivado Synthesis and Implementation"
puts "Project: $project_name"
puts "Top Module: $top_module"
puts "Target Part: $fpga_part"
puts "==============================================="

# Create output directories
file mkdir $output_dir
file mkdir $reports_dir

# Create project
create_project $project_name $output_dir -part $fpga_part -force

# Add source files
add_files {
    ../src/quant.sv
    ../src/quant_top.sv
}

# Add constraints
add_files -fileset constrs_1 ../constraints/timing.xdc

# Set top module
set_property top $top_module [current_fileset]

# Set SystemVerilog file type
set_property file_type SystemVerilog [get_files *.sv]

puts "\n==============================================="
puts "Running Synthesis"
puts "==============================================="

# Synthesis settings for high performance
set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE PerformanceOptimized [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY rebuilt [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.KEEP_EQUIVALENT_REGISTERS true [get_runs synth_1]

# Launch synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check synthesis status
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed!"
}

puts "Synthesis completed successfully!"

# Open synthesized design
open_run synth_1

# Generate synthesis reports
puts "\nGenerating Synthesis Reports..."
report_timing_summary -file $reports_dir/post_synth_timing_summary.rpt
report_utilization -file $reports_dir/post_synth_utilization.rpt
report_power -file $reports_dir/post_synth_power.rpt
report_drc -file $reports_dir/post_synth_drc.rpt

# Check timing
set slack [get_property SLACK [get_timing_paths]]
puts "Post-Synthesis Slack: $slack ns"

puts "\n==============================================="
puts "Running Implementation"
puts "==============================================="

# Implementation settings for high performance
set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraPostPlacementOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AlternateCLBRouting [get_runs impl_1]

# Launch implementation
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check implementation status
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed!"
}

puts "Implementation completed successfully!"

# Open implemented design
open_run impl_1

# Generate implementation reports
puts "\nGenerating Implementation Reports..."
report_timing_summary -file $reports_dir/post_impl_timing_summary.rpt
report_timing -sort_by slack -max_paths 10 -file $reports_dir/post_impl_timing_detail.rpt
report_utilization -hierarchical -file $reports_dir/post_impl_utilization.rpt
report_power -file $reports_dir/post_impl_power.rpt
report_drc -file $reports_dir/post_impl_drc.rpt
report_clock_networks -file $reports_dir/clock_networks.rpt

# Check final timing
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]

puts "\n==============================================="
puts "Final Results"
puts "==============================================="
puts "Worst Negative Slack (WNS): $wns ns"
puts "Worst Hold Slack (WHS): $whs ns"

if {$wns < 0} {
    puts "WARNING: Timing not met! WNS is negative."
} else {
    puts "SUCCESS: Timing constraints met!"
}

# Calculate achieved frequency
if {$wns >= 0} {
    set target_period 2.0
    set achieved_period [expr {$target_period - $wns}]
    set achieved_freq [expr {1000.0 / $achieved_period}]
    puts "Achieved Frequency: [format "%.2f" $achieved_freq] MHz"
}

# Generate bitstream (optional - uncomment if needed)
# puts "\nGenerating Bitstream..."
# launch_runs impl_1 -to_step write_bitstream
# wait_on_run impl_1

puts "\n==============================================="
puts "Reports saved in: $reports_dir"
puts "Project saved in: $output_dir"
puts "==============================================="

# Summary of utilization
set util [report_utilization -return_string]
puts "\nResource Utilization Summary:"
puts $util

puts "\nVivado flow completed successfully!"
