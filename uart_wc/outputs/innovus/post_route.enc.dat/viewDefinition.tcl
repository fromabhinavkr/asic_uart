if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name lib_wc\
   -timing\
    [list ${::IMEX::libVar}/mmmc/u055lsclpmvbpr_108c125_wc.lib]
create_rc_corner -name rc_wc\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0
create_delay_corner -name dc_wc\
   -library_set lib_wc\
   -rc_corner rc_wc
create_constraint_mode -name cmode\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/cmode/cmode.sdc]
create_analysis_view -name av_wc -constraint_mode cmode -delay_corner dc_wc -latency_file ${::IMEX::dataVar}/mmmc/views/av_wc/latency.sdc
set_analysis_view -setup [list av_wc] -hold [list av_wc]
