set_units -time ns -capacitance pF
############################################################
# CLOCK DEFINITION
############################################################

create_clock -name clk -period 10 [get_ports clk]
# 100 MHz system clock

############################################################
# INPUT DELAYS (excluding clock)
############################################################

set_input_delay 2 -clock clk [all_inputs -no_clocks]

############################################################
# OUTPUT DELAYS
############################################################

set_output_delay 2 -clock clk [all_outputs]

############################################################
# ASYNCHRONOUS INPUTS (BUTTONS)
############################################################

set_false_path -from [get_ports {btnu btnd}]

############################################################
# DHT SENSOR LINE (ASYNC + BIDIRECTIONAL)
############################################################

set_false_path -from [get_ports dht_in]
set_false_path -to   [get_ports dht_out]
set_false_path -to   [get_ports dht_oe]

############################################################
# UART TX (OPTIONAL TIGHTER CONTROL)
############################################################

# UART is slower → relaxed timing (optional)
set_output_delay 5 -clock clk [get_ports tx]
