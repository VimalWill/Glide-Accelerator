####################################################################################
# Block Design Creation Script - PS + PL Integration
#
# This script creates a complete Zynq UltraScale+ block design with:
#   - Zynq PS (ARM Cortex-A53 cores)
#   - Systolic Accelerator IP (PL)
#   - AXI Interconnect
#   - AXI DMA for data transfer
#   - Interrupt controller
#
# Usage:
#   vivado -mode batch -source create_bd.tcl
#   OR
#   source create_bd.tcl (within Vivado TCL console)
#
# Target: Zynq UltraScale+ (ZCU102/ZCU104/etc.)
####################################################################################

set design_name "zynq_systolic_bd"

puts "=========================================="
puts "Creating Block Design: $design_name"
puts "=========================================="

# Create block design
create_bd_design $design_name

# Set current block design
current_bd_design $design_name

####################################################################################
# Create Zynq UltraScale+ Processing System
####################################################################################
puts "\[INFO\] Adding Zynq UltraScale+ PS..."

create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0

# Apply board preset (if available)
# apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" } [get_bd_cells zynq_ultra_ps_e_0]

# Configure PS
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {1} \
    CONFIG.PSU__USE__S_AXI_GP0 {0} \
    CONFIG.PSU__USE__IRQ0 {1} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {128} \
    CONFIG.PSU__MAXIGP1__DATA_WIDTH {128} \
] [get_bd_cells zynq_ultra_ps_e_0]

####################################################################################
# Add Processor System Reset
####################################################################################
puts "\[INFO\] Adding Processor System Reset..."

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] [get_bd_pins proc_sys_reset_0/ext_reset_in]

####################################################################################
# Add Systolic Accelerator IP
####################################################################################
puts "\[INFO\] Adding Systolic Accelerator IP..."

# VLNV: vendor:library:name:version (must match create_ip.tcl)
create_bd_cell -type ip -vlnv user:user:systolic_accelerator:1.0 systolic_accel_0

# Configure accelerator parameters
set_property -dict [list \
    CONFIG.ROWS {32} \
    CONFIG.COLS {16} \
    CONFIG.DATA_WIDTH {8} \
    CONFIG.QUANT_UNITS {64} \
] [get_bd_cells systolic_accel_0]

####################################################################################
# Add AXI Interconnect for Control Path
####################################################################################
puts "\[INFO\] Adding AXI Interconnect..."

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0

set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
] [get_bd_cells axi_interconnect_0]

####################################################################################
# Add AXI DMA for Data Transfer
####################################################################################
puts "\[INFO\] Adding AXI DMA controllers..."

# DMA for input data (A and B matrices)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_input

set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axi_mm2s_data_width {128} \
    CONFIG.c_m_axis_mm2s_tdata_width {128} \
    CONFIG.c_mm2s_burst_size {16} \
] [get_bd_cells axi_dma_input]

# DMA for output data (results)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_output

set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_m_axi_s2mm_data_width {128} \
    CONFIG.c_s_axis_s2mm_tdata_width {128} \
    CONFIG.c_s2mm_burst_size {16} \
] [get_bd_cells axi_dma_output]

####################################################################################
# Add AXI SmartConnect for High-Performance Data Path
####################################################################################
puts "\[INFO\] Adding AXI SmartConnect for HP ports..."

create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hp0

set_property -dict [list \
    CONFIG.NUM_SI {2} \
    CONFIG.NUM_MI {1} \
] [get_bd_cells axi_smc_hp0]

####################################################################################
# Add AXI Interrupt Controller
####################################################################################
puts "\[INFO\] Adding AXI Interrupt Controller..."

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_intc:4.1 axi_intc_0

set_property -dict [list \
    CONFIG.C_IRQ_CONNECTION {1} \
] [get_bd_cells axi_intc_0]

####################################################################################
# Add Concat for combining interrupts
####################################################################################
puts "\[INFO\] Adding interrupt concatenation..."

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0

set_property -dict [list \
    CONFIG.NUM_PORTS {3} \
] [get_bd_cells xlconcat_0]

####################################################################################
# Make Connections - Clock and Reset
####################################################################################
puts "\[INFO\] Connecting clocks and resets..."

# Connect clocks
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins systolic_accel_0/aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_dma_input/s_axi_lite_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_dma_input/m_axi_mm2s_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_dma_output/s_axi_lite_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_dma_output/m_axi_s2mm_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_smc_hp0/aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_intc_0/s_axi_aclk]

# Connect resets
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins systolic_accel_0/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_interconnect_0/M00_ARESETN]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_dma_input/axi_resetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_dma_output/axi_resetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_smc_hp0/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_intc_0/s_axi_aresetn]

####################################################################################
# Make Connections - AXI Control Interface
####################################################################################
puts "\[INFO\] Connecting AXI control interfaces..."

# PS M_AXI_HPM0_FPD -> AXI Interconnect
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# AXI Interconnect -> Systolic Accelerator control
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins systolic_accel_0/s_axi]

####################################################################################
# Make Connections - AXI Stream Data Path
####################################################################################
puts "\[INFO\] Connecting AXI Stream data interfaces..."

# DMA MM2S (input) -> Systolic Accelerator input
connect_bd_intf_net [get_bd_intf_pins axi_dma_input/M_AXIS_MM2S] [get_bd_intf_pins systolic_accel_0/s_axis]

# Systolic Accelerator output -> DMA S2MM (output)
connect_bd_intf_net [get_bd_intf_pins systolic_accel_0/m_axis] [get_bd_intf_pins axi_dma_output/S_AXIS_S2MM]

####################################################################################
# Make Connections - DMA Memory Access (HP Ports)
####################################################################################
puts "\[INFO\] Connecting DMA to HP memory ports..."

# DMA read/write masters -> SmartConnect
connect_bd_intf_net [get_bd_intf_pins axi_dma_input/M_AXI_MM2S] [get_bd_intf_pins axi_smc_hp0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_output/M_AXI_S2MM] [get_bd_intf_pins axi_smc_hp0/S01_AXI]

# SmartConnect -> PS S_AXI_HP0_FPD (DDR access)
connect_bd_intf_net [get_bd_intf_pins axi_smc_hp0/M00_AXI] [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]

####################################################################################
# Make Connections - Interrupts
####################################################################################
puts "\[INFO\] Connecting interrupts..."

# Concatenate interrupts
connect_bd_net [get_bd_pins systolic_accel_0/interrupt] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_dma_input/mm2s_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins axi_dma_output/s2mm_introut] [get_bd_pins xlconcat_0/In2]

# Concat output -> Interrupt controller
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins axi_intc_0/intr]

# Interrupt controller -> PS IRQ
connect_bd_net [get_bd_pins axi_intc_0/irq] [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]

####################################################################################
# Address Assignments
####################################################################################
puts "\[INFO\] Assigning addresses..."

# Create address segments
assign_bd_address

# Customize address ranges (optional)
set_property range 64K [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_systolic_accel_0_s_axi}]
set_property offset 0xA0000000 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_systolic_accel_0_s_axi}]

set_property range 64K [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_axi_dma_input_Reg}]
set_property offset 0xA0010000 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_axi_dma_input_Reg}]

set_property range 64K [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_axi_dma_output_Reg}]
set_property offset 0xA0020000 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_axi_dma_output_Reg}]

set_property range 64K [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_axi_intc_0_Reg}]
set_property offset 0xA0030000 [get_bd_addr_segs {zynq_ultra_ps_e_0/Data/SEG_axi_intc_0_Reg}]

####################################################################################
# Validate and Save
####################################################################################
puts "\[INFO\] Validating design..."
regenerate_bd_layout
validate_bd_design

puts "\[INFO\] Saving block design..."
save_bd_design

puts "=========================================="
puts "Block Design Created Successfully!"
puts "=========================================="
puts "Design: $design_name"
puts ""
puts "Memory Map:"
puts "  Systolic Accelerator: 0xA000_0000"
puts "  DMA Input:            0xA001_0000"
puts "  DMA Output:           0xA002_0000"
puts "  Interrupt Controller: 0xA003_0000"
puts ""
puts "Next Steps:"
puts "1. Generate HDL wrapper: make_wrapper -files [get_files $design_name.bd] -top"
puts "2. Add to project: add_files -norecurse $design_name.bd"
puts "3. Generate bitstream"
puts "=========================================="
