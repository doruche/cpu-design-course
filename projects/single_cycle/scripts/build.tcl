if {$argc != 3} {
    puts stderr "usage: build.tcl {synth|bitstream} PROJECT_XPR JOBS"
    exit 2
}

set action [lindex $argv 0]
set project_xpr [file normalize [lindex $argv 1]]
set jobs [lindex $argv 2]

if {$action ne "synth" && $action ne "bitstream"} {
    puts stderr "unknown action: $action"
    exit 2
}

proc require_complete {run_name} {
    set status [get_property STATUS [get_runs $run_name]]
    puts "$run_name status: $status"
    if {![string match "*Complete*" $status]} {
        error "$run_name did not complete"
    }
}

open_project $project_xpr
set project_dir [get_property DIRECTORY [current_project]]
set report_dir [file join $project_dir artifacts]
file mkdir $report_dir

update_compile_order -fileset sources_1
generate_target all [get_ips]

reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
require_complete synth_1

if {$action eq "synth"} {
    open_run synth_1
    report_timing_summary -file [file join $report_dir synth_timing_summary.rpt]
    report_utilization -file [file join $report_dir synth_utilization.rpt]
    close_project
    exit 0
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
require_complete impl_1
open_run impl_1

report_timing_summary -file [file join $report_dir timing_summary.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_power -file [file join $report_dir power.rpt]

set impl_dir [get_property DIRECTORY [get_runs impl_1]]
foreach bit_file [glob -nocomplain [file join $impl_dir *.bit]] {
    file copy -force $bit_file $report_dir
}

close_project
