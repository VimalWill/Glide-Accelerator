####################################################################################
# Block Design Creation Script - GUI Mode
#
# Opens Vivado GUI and creates the PS-PL block design interactively
# You can see the design being created and modify it as needed
#
# Usage:
#   vivado -mode gui -source create_bd_gui.tcl
####################################################################################

# First, package the IP if not already done
set script_dir [file dirname [file normalize [info script]]]
set hw_dir [file dirname $script_dir]
set ip_repo_dir ${hw_dir}/ip_repo

# Create a new project for the block design
set design_name "zynq_systolic_simple"
set project_name "zynq_systolic_project"

puts "=========================================="
puts "Creating Vivado Project with Block Design"
puts "=========================================="

# Create project in GUI mode
create_project $project_name ${hw_dir}/vivado_bd_project -part xczu9eg-ffvb1156-2-e -force

# Add IP repository
set_property ip_repo_paths ${ip_repo_dir} [current_project]
update_ip_catalog

# Now source the simplified BD creation script
source ${script_dir}/create_bd_simple.tcl

# Open the block design in GUI
open_bd_design [get_files ${design_name}.bd]

puts "=========================================="
puts "Block Design opened in GUI!"
puts "=========================================="
puts "You can now:"
puts "  - View the PS-PL connections"
puts "  - Modify the design"
puts "  - Run Design Rule Checks"
puts "  - Generate HDL wrapper"
puts "  - Generate bitstream"
puts "=========================================="
