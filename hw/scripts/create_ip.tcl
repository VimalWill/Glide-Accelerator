####################################################################################
# IP Packaging Script for Systolic Array Accelerator
#
# This script packages the AXI-wrapped systolic array as a Vivado IP
# that can be used in Block Design and connected to Zynq PS
#
# Usage:
#   vivado -mode batch -source create_ip.tcl
####################################################################################

# Set project paths
set script_dir [file dirname [file normalize [info script]]]
set hw_dir [file dirname $script_dir]
set src_dir ${hw_dir}/src
set ip_dir ${hw_dir}/ip_repo

# IP Information
set ip_name "systolic_accelerator"
set ip_display_name "Systolic Array Accelerator"
set ip_description "32x16 Systolic Array with INT8 Quantization for Vision Transformers"
set vendor "user"
set library "user"
set version "1.0"
set ip_version "1.0"

puts "=========================================="
puts "Creating IP: $ip_display_name"
puts "=========================================="

# Create IP directory
file mkdir $ip_dir

# Create new IP project
create_project managed_ip_project ${ip_dir}/managed_ip_project -part xczu9eg-ffvb1156-2-e -ip -force

# Add source files
puts "\[INFO\] Adding source files..."
add_files -norecurse \
    ${src_dir}/axi_systolic_wrapper.sv \
    ${src_dir}/systolic_quant_32x16.sv \
    ${src_dir}/systolic_mac_rect.sv \
    ${src_dir}/pe.sv \
    ${src_dir}/accumulator_bank.sv \
    ${src_dir}/quant_shared.sv \
    ${src_dir}/quant.sv

# Set top module
set_property top axi_systolic_wrapper [current_fileset]
update_compile_order -fileset sources_1

# Package IP
puts "\[INFO\] Packaging IP..."
ipx::package_project -root_dir ${ip_dir}/${ip_name}_v${version} -vendor $vendor -library $library -taxonomy /UserIP -import_files -set_current false -force

# Open packaged IP for editing
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory ${ip_dir}/${ip_name}_v${version} ${ip_dir}/${ip_name}_v${version}/component.xml

# Set IP identification
set core [ipx::current_core]
set_property NAME $ip_name $core
set_property DISPLAY_NAME $ip_display_name $core
set_property DESCRIPTION $ip_description $core
set_property VERSION $ip_version $core

# Set supported families
set_property SUPPORTED_FAMILIES { \
    zynquplus Production \
    zynq Production \
    virtexuplus Production \
    kintexuplus Production \
    virtexu Production \
    kintexu Production \
} $core

puts "\[INFO\] Configuring AXI interfaces..."

# Associate clock with interfaces
ipx::associate_bus_interfaces -busif s_axi -clock aclk $core
ipx::associate_bus_interfaces -busif s_axis -clock aclk $core
ipx::associate_bus_interfaces -busif m_axis -clock aclk $core

# Infer AXI4-Lite slave interface
ipx::infer_bus_interface {s_axi_awaddr s_axi_awprot s_axi_awvalid s_axi_awready \
                          s_axi_wdata s_axi_wstrb s_axi_wvalid s_axi_wready \
                          s_axi_bresp s_axi_bvalid s_axi_bready \
                          s_axi_araddr s_axi_arprot s_axi_arvalid s_axi_arready \
                          s_axi_rdata s_axi_rresp s_axi_rvalid s_axi_rready} \
                          xilinx.com:interface:aximm_rtl:1.0 $core

# Infer AXI4-Stream slave interface
ipx::infer_bus_interface {s_axis_tdata s_axis_tvalid s_axis_tready s_axis_tlast} \
                          xilinx.com:interface:axis_rtl:1.0 $core

# Infer AXI4-Stream master interface
ipx::infer_bus_interface {m_axis_tdata m_axis_tvalid m_axis_tready m_axis_tlast} \
                          xilinx.com:interface:axis_rtl:1.0 $core

# Add interrupt signal
ipx::add_port_map IRQ [ipx::get_bus_interfaces interrupt -of_objects $core]
set_property PHYSICAL_NAME interrupt [ipx::get_port_maps IRQ -of_objects [ipx::get_bus_interfaces interrupt -of_objects $core]]

puts "\[INFO\] Adding customization parameters..."

# Add customization parameters (ROWS, COLS, etc.)
ipx::add_user_parameter ROWS $core
set_property value_resolve_type user [ipx::get_user_parameters ROWS -of_objects $core]
set_property display_name {Array Rows} [ipx::get_user_parameters ROWS -of_objects $core]
set_property value {32} [ipx::get_user_parameters ROWS -of_objects $core]
set_property value_format long [ipx::get_user_parameters ROWS -of_objects $core]

ipx::add_user_parameter COLS $core
set_property value_resolve_type user [ipx::get_user_parameters COLS -of_objects $core]
set_property display_name {Array Columns} [ipx::get_user_parameters COLS -of_objects $core]
set_property value {16} [ipx::get_user_parameters COLS -of_objects $core]
set_property value_format long [ipx::get_user_parameters COLS -of_objects $core]

ipx::add_user_parameter DATA_WIDTH $core
set_property value_resolve_type user [ipx::get_user_parameters DATA_WIDTH -of_objects $core]
set_property display_name {Data Width (bits)} [ipx::get_user_parameters DATA_WIDTH -of_objects $core]
set_property value {8} [ipx::get_user_parameters DATA_WIDTH -of_objects $core]
set_property value_format long [ipx::get_user_parameters DATA_WIDTH -of_objects $core]

ipx::add_user_parameter QUANT_UNITS $core
set_property value_resolve_type user [ipx::get_user_parameters QUANT_UNITS -of_objects $core]
set_property display_name {Quantization Units} [ipx::get_user_parameters QUANT_UNITS -of_objects $core]
set_property value {64} [ipx::get_user_parameters QUANT_UNITS -of_objects $core]
set_property value_format long [ipx::get_user_parameters QUANT_UNITS -of_objects $core]

# Add address space for AXI4-Lite
ipx::add_address_space s_axi $core
set_property range 64 [ipx::get_address_spaces s_axi -of_objects $core]
set_property width 32 [ipx::get_address_spaces s_axi -of_objects $core]

# Set memory map
ipx::add_memory_map s_axi $core
set_property slave_memory_map_ref s_axi [ipx::get_bus_interfaces s_axi -of_objects $core]

ipx::add_address_block Reg0 [ipx::get_memory_maps s_axi -of_objects $core]
set_property range 64 [ipx::get_address_blocks Reg0 -of_objects [ipx::get_memory_maps s_axi -of_objects $core]]
set_property width 32 [ipx::get_address_blocks Reg0 -of_objects [ipx::get_memory_maps s_axi -of_objects $core]]

# Add register definitions for documentation
puts "\[INFO\] Adding register map documentation..."

set addr_block [ipx::get_address_blocks Reg0 -of_objects [ipx::get_memory_maps s_axi -of_objects $core]]

# CTRL Register (0x00)
ipx::add_register CTRL $addr_block
set_property address_offset 0x00 [ipx::get_registers CTRL -of_objects $addr_block]
set_property size 32 [ipx::get_registers CTRL -of_objects $addr_block]
set_property description "Control Register: [0]=enable [1]=reset [2]=start" [ipx::get_registers CTRL -of_objects $addr_block]

# STATUS Register (0x04)
ipx::add_register STATUS $addr_block
set_property address_offset 0x04 [ipx::get_registers STATUS -of_objects $addr_block]
set_property size 32 [ipx::get_registers STATUS -of_objects $addr_block]
set_property description "Status Register: [0]=busy [1]=done [2]=overflow" [ipx::get_registers STATUS -of_objects $addr_block]

# ACCUM_CTRL Register (0x08)
ipx::add_register ACCUM_CTRL $addr_block
set_property address_offset 0x08 [ipx::get_registers ACCUM_CTRL -of_objects $addr_block]
set_property size 32 [ipx::get_registers ACCUM_CTRL -of_objects $addr_block]
set_property description "Accumulator Control: [0]=enable [1]=clear" [ipx::get_registers ACCUM_CTRL -of_objects $addr_block]

# QUANT_CTRL Register (0x0C)
ipx::add_register QUANT_CTRL $addr_block
set_property address_offset 0x0C [ipx::get_registers QUANT_CTRL -of_objects $addr_block]
set_property size 32 [ipx::get_registers QUANT_CTRL -of_objects $addr_block]
set_property description "Quantization Control: [0]=enable" [ipx::get_registers QUANT_CTRL -of_objects $addr_block]

# SCALE Register (0x10)
ipx::add_register SCALE $addr_block
set_property address_offset 0x10 [ipx::get_registers SCALE -of_objects $addr_block]
set_property size 32 [ipx::get_registers SCALE -of_objects $addr_block]
set_property description "Quantization Scale Factor" [ipx::get_registers SCALE -of_objects $addr_block]

# SHIFT Register (0x14)
ipx::add_register SHIFT $addr_block
set_property address_offset 0x14 [ipx::get_registers SHIFT -of_objects $addr_block]
set_property size 32 [ipx::get_registers SHIFT -of_objects $addr_block]
set_property description "Quantization Shift Amount" [ipx::get_registers SHIFT -of_objects $addr_block]

# ROWS_COLS Register (0x18)
ipx::add_register ROWS_COLS $addr_block
set_property address_offset 0x18 [ipx::get_registers ROWS_COLS -of_objects $addr_block]
set_property size 32 [ipx::get_registers ROWS_COLS -of_objects $addr_block]
set_property description "Array Dimensions (Read-only)" [ipx::get_registers ROWS_COLS -of_objects $addr_block]
set_property access read-only [ipx::get_registers ROWS_COLS -of_objects $addr_block]

# VERSION Register (0x1C)
ipx::add_register VERSION $addr_block
set_property address_offset 0x1C [ipx::get_registers VERSION -of_objects $addr_block]
set_property size 32 [ipx::get_registers VERSION -of_objects $addr_block]
set_property description "IP Version (Read-only)" [ipx::get_registers VERSION -of_objects $addr_block]
set_property access read-only [ipx::get_registers VERSION -of_objects $addr_block]

# Add logo/icon (optional)
# set_property logo_file ${hw_dir}/logo.png $core

# Create GUI customization
puts "\[INFO\] Creating GUI customization..."
ipx::create_xgui_files $core
ipx::update_checksums $core

# Save and close
puts "\[INFO\] Saving IP..."
ipx::save_core $core

close_project

puts "=========================================="
puts "IP Creation Complete!"
puts "=========================================="
puts "IP Location: ${ip_dir}/${ip_name}_v${version}"
puts ""
puts "To use this IP in Vivado:"
puts "1. Settings -> IP -> Repository"
puts "2. Add: ${ip_dir}"
puts "3. Open Block Design"
puts "4. Add IP: $ip_display_name"
puts "=========================================="
