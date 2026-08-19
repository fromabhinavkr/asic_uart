############################################################
# CLOCK DEFINITION
############################################################

create_clock -name clk -period 10 [get_ports clk]
# 100 MHz system clock

############################################################
# INPUT DELAYS (excluding clock)
############################################################

set_input_delay 2 -clock clk \
[remove_from_collection [all_inputs] [get_ports clk]]

############################################################
# OUTPUT DELAYS
############################################################

set_output_delay 2 -clock clk [all_outputs]

############################################################
# ASYNCHRONOUS INPUTS (BUTTONS)
############################################################

set_false_path -from [get_ports {btnc btnu btnd}]

############################################################
# DHT SENSOR LINE (ASYNC + BIDIRECTIONAL)
############################################################

set_false_path -from [get_ports dht_data]
set_false_path -to   [get_ports dht_data]

############################################################
# UART TX (OPTIONAL TIGHTER CONTROL)
############################################################

# UART is slower → relaxed timing (optional)
set_output_delay 5 -clock clk [get_ports tx]

############################################################
# END
#########################################################