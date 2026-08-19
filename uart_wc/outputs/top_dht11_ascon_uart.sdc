# ####################################################################

#  Created by Genus(TM) Synthesis Solution 21.19-s055_1 on Tue Apr 21 15:47:32 +0530 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design top_dht11_ascon_uart

create_clock -name "clk" -period 10.0 -waveform {0.0 5.0} [get_ports clk]
set_false_path -from [list \
  [get_ports btnu]  \
  [get_ports btnd] ]
set_clock_gating_check -setup 0.0 
set_input_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports rst]
set_input_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports btnu]
set_input_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports btnd]
set_input_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports dht_in]
set_output_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports dht_out]
set_output_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports dht_oe]
set_output_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports {led[3]}]
set_output_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports {led[2]}]
set_output_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports {led[1]}]
set_output_delay -clock [get_clocks clk] -add_delay 2.0 [get_ports {led[0]}]
set_output_delay -clock [get_clocks clk] -add_delay 5.0 [get_ports tx]
set_wire_load_mode "top"
