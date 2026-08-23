###############################################################################
# Created by write_sdc
###############################################################################
current_design top_dht11_ascon_uart
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 10.0000 [get_ports {clk}]
set_propagated_clock [get_clocks {clk}]
set_input_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {btnd}]
set_input_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {btnu}]
set_input_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {dht_in}]
set_input_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {rst}]
set_output_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {dht_oe}]
set_output_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {dht_out}]
set_output_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {led[0]}]
set_output_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {led[1]}]
set_output_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {led[2]}]
set_output_delay 2.0000 -clock [get_clocks {clk}] -add_delay [get_ports {led[3]}]
set_output_delay 5.0000 -clock [get_clocks {clk}] -add_delay [get_ports {tx}]
set_false_path\
    -from [list [get_ports {btnd}]\
           [get_ports {btnu}]\
           [get_ports {dht_in}]]
set_false_path\
    -to [list [get_ports {dht_oe}]\
           [get_ports {dht_out}]]
###############################################################################
# Environment
###############################################################################
###############################################################################
# Design Rules
###############################################################################
