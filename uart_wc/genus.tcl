# ============================================================
# ENV SETUP
# ============================================================

set DESIGN_NAME "top_dht11_ascon_uart"
set TOP_MODULE  "top_dht11_ascon_uart"

if {![info exists ::env(PROJ_ROOT)]} {
    puts "ERROR: Please set PROJ_ROOT"
    exit 1
}
set PROJ_ROOT $::env(PROJ_ROOT)

# ============================================================
# INPUT FILES
# ============================================================

set RTL_FILES [list "$PROJ_ROOT/ascon128a.v"]
set SDC_FILE "$PROJ_ROOT/constraints.sdc"

# ============================================================
# LIBRARIES
# ============================================================

set TECH_LIB_PATH "/home/user1/project/UM055LSCLPMVBPR_C01_TAPEOUTKIT/synopsys"

set LIB_TYP "$TECH_LIB_PATH/u055lsclpmvbpr_120c25_tc.lib"
set LIB_WC  "$TECH_LIB_PATH/u055lsclpmvbpr_108c125_wc.lib"
set LIB_BC  "$TECH_LIB_PATH/u055lsclpmvbpr_132c-40_bc.lib"

set_db target_library [list $LIB_WC]
set_db link_library   [list $LIB_TYP $LIB_WC $LIB_BC]

# ============================================================
# OUTPUT
# ============================================================

set REPORT_DIR "reports"
set OUTPUT_DIR "outputs"
file mkdir $REPORT_DIR
file mkdir $OUTPUT_DIR

# ============================================================
# CLOCK GATING (DISABLED)
# ============================================================

set_db lp_insert_clock_gating false

# ============================================================
# DISABLE SCAN
# ============================================================

set_db use_scan_seqs false

# ============================================================
# READ RTL
# ============================================================

foreach rtl $RTL_FILES {
    if {![file exists $rtl]} {
        puts "ERROR: RTL not found $rtl"
        exit 1
    }
    read_hdl $rtl
}

elaborate $TOP_MODULE
current_design $TOP_MODULE

# ============================================================
# READ SDC
# ============================================================

if {![file exists $SDC_FILE]} {
    puts "ERROR: SDC file missing"
    exit 1
}

read_sdc $SDC_FILE

# ============================================================
# MMMC SETUP
# ============================================================

create_library_set -name lib_wc -timing [list $LIB_WC]
create_library_set -name lib_bc -timing [list $LIB_BC]

create_timing_condition -name tc_wc -library_set lib_wc
create_timing_condition -name tc_bc -library_set lib_bc

create_rc_corner -name rc_typ

create_delay_corner -name dc_wc -timing_condition tc_wc -rc_corner rc_typ
create_delay_corner -name dc_bc -timing_condition tc_bc -rc_corner rc_typ

create_constraint_mode -name cmode -sdc_files [list $SDC_FILE]

create_analysis_view -name av_wc -constraint_mode cmode -delay_corner dc_wc
create_analysis_view -name av_bc -constraint_mode cmode -delay_corner dc_bc

set_analysis_view -setup {av_wc} -hold {av_bc}

# ============================================================
# CLOCK CHECK
# ============================================================

if {[llength [get_clocks clk]] == 0} {
    puts "ERROR: Clock 'clk' not found!"
} else {
    puts "INFO: Clock detected successfully"
}

# ============================================================
# SYNTHESIS
# ============================================================

set_db auto_ungroup none
set_db syn_opt_effort high
set_db syn_global_effort high

syn_gen
syn_map
syn_opt

# ============================================================
# REPORTS
# ============================================================

report_power > $REPORT_DIR/power.rpt
report_area  > $REPORT_DIR/area.rpt
report_timing > $REPORT_DIR/timing.rpt
report_power -by_hierarchy -levels all > $REPORT_DIR/power_hierarchical.rpt

# ============================================================
# OUTPUT FILES
# ============================================================

write_hdl -mapped > $OUTPUT_DIR/${DESIGN_NAME}.v
write_sdc > $OUTPUT_DIR/${DESIGN_NAME}.sdc
write_sdf > $OUTPUT_DIR/${DESIGN_NAME}.sdf