####################################################################################
# Debug Signals TCL Script
# Add key signals to waveform viewer for debugging
####################################################################################

# Add all testbench signals
add_wave {{/systolic_quant_tb/*}}

# Add DUT top-level signals
add_wave {{/systolic_quant_tb/dut/*}}

# Add systolic array outputs (32-bit)
add_wave -group "Systolic Outputs" {{/systolic_quant_tb/dut/systolic_out}}

# Add accumulator outputs (32-bit)
add_wave -group "Accumulator Outputs" {{/systolic_quant_tb/dut/accum_out}}

# Add accumulator internal registers
add_wave -group "Accumulator Internals" {{/systolic_quant_tb/dut/u_accumulator/accum_regs}}
add_wave -group "Accumulator Internals" {{/systolic_quant_tb/dut/u_accumulator/overflow_flag}}

# Add quantization outputs
add_wave -group "Quant Outputs" {{/systolic_quant_tb/dut/quant_out}}

# Add control signals
add_wave -group "Control Signals" {{/systolic_quant_tb/dut/enable}}
add_wave -group "Control Signals" {{/systolic_quant_tb/dut/accum_enable}}
add_wave -group "Control Signals" {{/systolic_quant_tb/dut/accum_clear}}
add_wave -group "Control Signals" {{/systolic_quant_tb/dut/quant_enable}}
add_wave -group "Control Signals" {{/systolic_quant_tb/dut/systolic_valid}}
add_wave -group "Control Signals" {{/systolic_quant_tb/dut/quant_valid}}

# Configure wave window
wave zoomfull
