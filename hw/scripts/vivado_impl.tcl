####################################################################################
# Vivado Implementation TCL Script
# Project: Efficient Transformer Accelerator
# Purpose: Place & Route the synthesized design
####################################################################################

# Check if synthesis was run first
if {![file exists "./vivado_synth/systolic_quant_synth.xpr"]} {
    puts "ERROR: Synthesis project not found!"
    puts "Please run synthesis first: ./run_vivado.sh synth"
    exit 1
}

puts "=========================================="
puts "Vivado Implementation"
puts "=========================================="
puts "Opening synthesis project..."
puts ""

# Open the synthesis project
open_project ./vivado_synth/systolic_quant_synth.xpr

# Open the synthesized design
open_run synth_1

puts "=========================================="
puts "Running Implementation"
puts "=========================================="
puts ""

# Create implementation run if it doesn't exist
if {[get_runs impl_1] == ""} {
    create_run impl_1 -parent_run synth_1 -flow {Vivado Implementation 2023}
    puts "Created implementation run"
}

# Configure implementation strategies
# Options: Performance_Explore, Performance_ExplorePostRoutePhysOpt,
#          Area_Explore, Power_DefaultOpt, Congestion_SpreadLogic_high
set_property strategy Performance_Explore [get_runs impl_1]

puts "Implementation Strategy: Performance_Explore"
puts ""

# Launch implementation
puts "Launching implementation (this may take several minutes)..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check if implementation succeeded
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts ""
    puts "=========================================="
    puts "ERROR: Implementation Failed!"
    puts "=========================================="
    exit 1
}

puts ""
puts "=========================================="
puts "Implementation Complete!"
puts "=========================================="
puts ""

# Open implemented design
open_run impl_1

# Generate detailed reports
puts "Generating implementation reports..."
puts ""

# Timing reports
report_timing_summary -file ./vivado_synth/impl_timing_summary.rpt
puts "  Timing summary: impl_timing_summary.rpt"

report_timing -max_paths 10 -nworst 2 -file ./vivado_synth/impl_timing_detailed.rpt
puts "  Detailed timing (10 worst paths): impl_timing_detailed.rpt"

# Utilization reports
report_utilization -file ./vivado_synth/impl_utilization.rpt
puts "  Utilization: impl_utilization.rpt"

report_utilization -hierarchical -file ./vivado_synth/impl_utilization_hierarchical.rpt
puts "  Hierarchical utilization: impl_utilization_hierarchical.rpt"

# Power report
report_power -file ./vivado_synth/impl_power.rpt
puts "  Power: impl_power.rpt"

# Clock interaction report
report_clock_interaction -file ./vivado_synth/impl_clock_interaction.rpt
puts "  Clock interaction: impl_clock_interaction.rpt"

# Design rule check
report_drc -file ./vivado_synth/impl_drc.rpt
puts "  DRC: impl_drc.rpt"

# Methodology check (finds potential issues)
report_methodology -file ./vivado_synth/impl_methodology.rpt
puts "  Methodology: impl_methodology.rpt"

# Control sets (helps find logic optimization opportunities)
report_control_sets -verbose -file ./vivado_synth/impl_control_sets.rpt
puts "  Control sets: impl_control_sets.rpt"

puts ""
puts "=========================================="
puts "Timing Summary"
puts "=========================================="
report_timing_summary

puts ""
puts "=========================================="
puts "Utilization Summary"
puts "=========================================="
report_utilization

# Check timing closure
set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]

puts ""
puts "=========================================="
puts "Timing Closure Check"
puts "=========================================="
puts "  WNS (Worst Negative Slack - Setup): [format "%.3f" $wns] ns"
puts "  WHS (Worst Hold Slack):              [format "%.3f" $whs] ns"
puts ""

if {$wns >= 0 && $whs >= 0} {
    puts "  ✓ TIMING MET - All constraints satisfied!"
    puts ""
    puts "You can now generate a bitstream:"
    puts "  launch_runs impl_1 -to_step write_bitstream"
    puts "  wait_on_run impl_1"
} else {
    puts "  ✗ TIMING FAILED - Constraints not met"
    puts ""
    if {$wns < 0} {
        puts "Setup timing failed (WNS < 0):"
        puts "  - Reduce clock frequency in timing.xdc"
        puts "  - Add pipeline stages to critical paths"
        puts "  - Try different implementation strategies"
    }
    if {$whs < 0} {
        puts "Hold timing failed (WHS < 0):"
        puts "  - This usually indicates a problem with the design"
        puts "  - Check report_timing for hold violations"
    }
}

puts ""
puts "=========================================="
puts "All Reports Saved To:"
puts "=========================================="
puts "  ./vivado_synth/impl_*.rpt"
puts ""
puts "To view in GUI:"
puts "  vivado ./vivado_synth/systolic_quant_synth.xpr"
puts "  Then: Open Run -> impl_1"
puts ""
