if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name lib_typ\
   -timing\
    [list ${::IMEX::libVar}/mmmc/u055lsclpmvbpr_120c25_tc.lib]
create_rc_corner -name rc_typ\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0
create_delay_corner -name dc_typ\
   -library_set lib_typ\
   -rc_corner rc_typ
create_constraint_mode -name sdc_mode\
   -sdc_files\
    [list ${::IMEX::libVar}/mmmc/top_dht11_ascon_uart.sdc]
create_analysis_view -name av_typ -constraint_mode sdc_mode -delay_corner dc_typ
set_analysis_view -setup [list av_typ] -hold [list av_typ]
