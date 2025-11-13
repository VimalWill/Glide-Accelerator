# Timing Constraints for Requantization Module
# Target: High-frequency ASIC-style design

# Clock constraint - Set your target frequency here
# Example: 500 MHz (2.0 ns period) - adjust based on your target
create_clock -period 2.000 -name clk -waveform {0.000 1.000} [get_ports clk]

# Input delay constraints (relative to clock)
# Assume inputs arrive 0.5ns after clock edge
set_input_delay -clock clk -max 0.5 [get_ports {data_in[*]}]
set_input_delay -clock clk -max 0.5 [get_ports {scale_factor[*]}]
set_input_delay -clock clk -max 0.5 [get_ports {shift_amount[*]}]
set_input_delay -clock clk -max 0.5 [get_ports en]
set_input_delay -clock clk -max 0.5 [get_ports rst]

# Output delay constraints (relative to clock)
# Assume outputs must be stable 0.5ns before next clock edge
set_output_delay -clock clk -max 0.5 [get_ports {data_out[*]}]

# Clock uncertainty (for jitter, skew)
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]

# For synthesis: aggressive timing optimization
set_max_delay -from [all_inputs] -to [all_outputs] 2.0

# Disable timing on reset (asynchronous reset doesn't need timing check)
set_false_path -from [get_ports rst]
