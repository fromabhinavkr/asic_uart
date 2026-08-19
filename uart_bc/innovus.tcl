# ============================================================

# BASIC SETUP

# ============================================================

set DESIGN_NAME "top_dht11_ascon_uart"

if {![info exists ::env(PROJ_ROOT)]} {
puts "ERROR: Please set PROJ_ROOT"
exit 1
}
set PROJ_ROOT $::env(PROJ_ROOT)

# ============================================================

# PATHS

# ============================================================

set TECH_LIB_PATH "/home/user1/project/UM055LSCLPMVBPR_C01_TAPEOUTKIT"

set TECH_LEF     "$TECH_LIB_PATH/lef/tf/u055lsclpmvbpr_7m2t1f.lef"
set STDCELL_LEF  "$TECH_LIB_PATH/lef/u055lsclpmvbpr.lef"
set LIB_BC      "$TECH_LIB_PATH/synopsys/u055lsclpmvbpr_132c-40_bc.lib"
set LIB_WC      "$TECH_LIB_PATH/synopsys/u055lsclpmvbpr_108c125_wc.lib"

set NETLIST_FILE "$PROJ_ROOT/outputs/${DESIGN_NAME}.v"
set SDC_FILE     "$PROJ_ROOT/outputs/${DESIGN_NAME}.sdc"

set REPORT_DIR "$PROJ_ROOT/reports/innovus"
set OUTPUT_DIR "$PROJ_ROOT/outputs/innovus"

file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR

# ============================================================

# MMMC SETUP

# ============================================================

create_library_set -name lib_bc -timing [list $LIB_BC]
create_rc_corner -name rc_bc
create_delay_corner -name dc_bc -library_set lib_bc -rc_corner rc_bc

create_constraint_mode -name cmode -sdc_files [list $SDC_FILE]
create_analysis_view -name av_bc -constraint_mode cmode -delay_corner dc_bc

# WC --> SETUP (you MUST have WC lib)
create_library_set -name lib_wc -timing [list $LIB_WC]
create_delay_corner -name dc_wc -library_set lib_wc -rc_corner rc_bc
create_analysis_view -name av_setup -constraint_mode cmode -delay_corner dc_wc
create_analysis_view -name av_hold -constraint_mode cmode -delay_corner dc_bc

# ============================================================

# INIT DESIGN

# ============================================================

set init_lef_file [list $TECH_LEF $STDCELL_LEF]
set init_verilog  $NETLIST_FILE
set init_top_cell $DESIGN_NAME

set init_pwr_net VDD
set init_gnd_net VSS

init_design -setup {av_setup} -hold {av_hold}

# ============================================================

# POWER CONNECTION

# ============================================================

globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *

# ============================================================

# FLOORPLAN

# ============================================================

floorPlan -r 1.2 0.7 20 20 20 20

# ============================================================

# POWER PLANNING

# ============================================================

#addStripe -nets {VDD VSS} -layer ME5 -direction vertical -width 1.5 -spacing 1 -set_to_set_distance 15
#addStripe -nets {VDD VSS} -layer ME4 -direction horizontal -width 1.5 -spacing 1 -set_to_set_distance 15
addRing -nets {VDD VSS} -type core_rings -follow core -layer {top ME7 bottom ME7 left ME6 right ME6} -width 2 -spacing 1 -offset 1

addStripe -nets {VDD VSS} -layer ME5 -direction vertical -width 1.5 -spacing 1 -set_to_set_distance 15
addStripe -nets {VDD VSS} -layer ME4 -direction horizontal -width 1.5 -spacing 1 -set_to_set_distance 15

# Improved power routing with better connectivity
setSrouteMode \
    -viaConnectToShape {ring stripe blockring} \
    -allowJogging 1 \
    -allowLayerChange 1

# Connect standard cell rails to power grid
sroute -nets {VDD VSS} -connect {corePin} \
    -layerChangeRange {ME1 ME7} \
    -targetViaLayerRange {ME1 ME7}

# Connect any floating stripes to complete power grid
sroute -nets {VDD VSS} -connect {floatingStripe padPin padRing} \
    -layerChangeRange {ME1 ME7}

sroute -nets {VDD VSS}

# ============================================================

# PLACEMENT

# ============================================================

setPlaceMode -congEffort high
setPlaceMode -place_global_place_io_pins true

setOptMode -powerEffort high

place_opt_design

# ============================================================

# CLOCK TREE SYNTHESIS (CTS)

# ============================================================

puts "INFO: Running Clock Tree Synthesis..."

# Define clock gating cells for CCOpt (if any exist in your library)
set clock_gating_cells [list \
    LAGCEPOM2DP  LAGCEPOM3DP  LAGCEPOM4DP  LAGCEPOM6DP  LAGCEPOM8DP  LAGCEPOM12DP  LAGCEPOM16DP  LAGCEPOM20DP \
    LAGCESOM2DP  LAGCESOM3DP  LAGCESOM4DP  LAGCESOM6DP  LAGCESOM8DP  LAGCESOM12DP  LAGCESOM16DP  LAGCESOM20DP \
]

# Mark ICG cells for CCOpt (will only work if cells exist in library)
foreach cg $clock_gating_cells {
    catch {set_db [get_db lib_cells -if {.name == $cg}] .is_clock_gating_cell true}
}

# Run CTS
clock_opt -cts

# Report CTS results
report_clock_gating > $REPORT_DIR/clock_gating_summary.rpt

# ============================================================
# CTS REPORTS
# ============================================================

puts "INFO: Generating CTS reports..."

# CTS timing reports (per-corner)
set_analysis_view -setup {av_setup} -hold {av_hold}
report_timing -view av_setup -max_paths 10 > $REPORT_DIR/timing_post_cts_setup.rpt
report_timing -view av_hold -early -max_paths 10 > $REPORT_DIR/timing_post_cts_hold.rpt

# CTS-specific reports (basic timing analysis)
report_timing -max_paths 20 > $REPORT_DIR/clock_tree_summary.rpt

# Power after CTS
report_power -view av_hold > $REPORT_DIR/power_post_cts.rpt

# Area after CTS  
report_area > $REPORT_DIR/area_post_cts.rpt

puts "INFO: CTS reports completed"

# ============================================================

# DISABLE SI (IMPORTANT)

# ============================================================

setDelayCalMode -SIAware false

# ============================================================

# ROUTING

# ============================================================

route_opt_design

# ============================================================

# ============================================================
# POST ROUTE
# ============================================================

optDesign -postRoute -setup
optDesign -postRoute -hold
saveDesign $OUTPUT_DIR/post_route.enc

# ============================================================
# REPORTS
# ============================================================

report_timing > $REPORT_DIR/timing.rpt
report_power -view av_hold > $REPORT_DIR/power.rpt
report_area   > $REPORT_DIR/area.rpt

# Setup report (WC only - av_setup is for late/hold analysis)
set_analysis_view -setup {av_setup} -hold {av_hold}
report_timing -view av_setup -max_paths 20 > $REPORT_DIR/setup_wc.rpt

# Hold report (BC analysis) - using av_hold view with -early flag for hold timing
report_timing -view av_hold -early -max_paths 20 > $REPORT_DIR/hold.rpt

# Additional hold analysis
report_timing -view av_hold -early -max_paths 50 > $REPORT_DIR/hold_detailed.rpt

verify_drc -report $REPORT_DIR/drc.rpt
verify_connectivity -report $REPORT_DIR/connectivity.rpt

# ============================================================
# OUTPUT
# ============================================================

defOut -floorplan -routing $OUTPUT_DIR/final.def
saveNetlist $OUTPUT_DIR/final.v
write_sdf $OUTPUT_DIR/final.sdf

puts "========================================="
puts " FLOW COMPLETED SUCCESSFULLY "
puts "========================================="