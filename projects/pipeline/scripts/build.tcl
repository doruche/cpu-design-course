if {$argc != 4} {
    puts stderr "usage: build.tcl {synth|bitstream} PROJECT_XPR JOBS CANDIDATE_COE|-"
    exit 2
}

set action [lindex $argv 0]
set project_xpr [file normalize [lindex $argv 1]]
set jobs [lindex $argv 2]
set candidate_coe [lindex $argv 3]

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

proc write_fact {stream key value} {
    puts $stream "$key\t$value"
}

proc normalize_ip_file {ip_object value} {
    if {[file pathtype $value] eq "absolute"} {
        return [file normalize $value]
    }
    set ip_file [file normalize [get_property IP_FILE $ip_object]]
    return [file normalize [file join [file dirname $ip_file] $value]]
}

open_project $project_xpr
set vivado_version [version -short]
if {$vivado_version ne "2023.2"} {
    error "Stage 5 requires Vivado 2023.2, got $vivado_version"
}
set project_dir [get_property DIRECTORY [current_project]]
set report_dir [file join $project_dir artifacts]
file mkdir $report_dir

set bram_ip [get_ips bram_axi]
if {[llength $bram_ip] != 1} {
    error "canonical project must contain exactly one bram_axi IP"
}
if {$action eq "bitstream" && $candidate_coe eq "-"} {
    error "bitstream action requires an explicit candidate COE"
}
if {$candidate_coe ne "-"} {
    set candidate_coe [file normalize $candidate_coe]
    if {![file isfile $candidate_coe]} {
        error "candidate COE does not exist: $candidate_coe"
    }
    set_property -dict [list CONFIG.Load_Init_File {true} \
                             CONFIG.Coe_File $candidate_coe] $bram_ip
    set actual_candidate_coe [normalize_ip_file \
        $bram_ip [get_property CONFIG.Coe_File $bram_ip]]
    if {![string equal -nocase $actual_candidate_coe $candidate_coe]} {
        error "bram_axi did not consume the requested candidate COE"
    }
} else {
    set actual_candidate_coe [normalize_ip_file \
        $bram_ip [get_property CONFIG.Coe_File $bram_ip]]
}

set bram_width [get_property CONFIG.Write_Width_A $bram_ip]
set bram_depth [get_property CONFIG.Write_Depth_A $bram_ip]
if {$bram_width != 32 || $bram_depth < 38400} {
    error "bram_axi is smaller than the 38400-word Stage 5 contract"
}

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
    set facts [open [file join $report_dir build_facts.tsv] w]
    write_fact $facts schema 1
    write_fact $facts action $action
    write_fact $facts vivado_version $vivado_version
    write_fact $facts part [get_property PART [current_project]]
    write_fact $facts synth_complete 1
    write_fact $facts impl_complete 0
    write_fact $facts bram_width_bits $bram_width
    write_fact $facts bram_depth_words $bram_depth
    write_fact $facts requested_coe $candidate_coe
    write_fact $facts actual_coe $actual_candidate_coe
    close $facts
    close_project
    exit 0
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
require_complete impl_1
open_run impl_1

report_timing_summary -file [file join $report_dir timing_summary.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
report_power -file [file join $report_dir power.rpt]

set drc_errors [llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]
set drc_critical [llength \
    [get_drc_violations -quiet -filter {SEVERITY == "Critical Warning"}]]
set methodology_critical [llength \
    [get_methodology_violations -quiet \
        -filter {SEVERITY == "Critical Warning"}]]

set impl_dir [get_property DIRECTORY [get_runs impl_1]]
foreach bit_file [glob -nocomplain [file join $impl_dir *.bit]] {
    file copy -force $bit_file $report_dir
}

set bit_files [glob -nocomplain [file join $report_dir *.bit]]
if {[llength $bit_files] != 1} {
    error "expected exactly one candidate bitstream, found [llength $bit_files]"
}

set facts [open [file join $report_dir build_facts.tsv] w]
write_fact $facts schema 1
write_fact $facts action $action
write_fact $facts vivado_version $vivado_version
write_fact $facts part [get_property PART [current_project]]
write_fact $facts synth_complete 1
write_fact $facts impl_complete 1
write_fact $facts bram_width_bits $bram_width
write_fact $facts bram_depth_words $bram_depth
write_fact $facts requested_coe $candidate_coe
write_fact $facts actual_coe $actual_candidate_coe
write_fact $facts bitstream [lindex $bit_files 0]
write_fact $facts drc_error_count $drc_errors
write_fact $facts drc_critical_warning_count $drc_critical
write_fact $facts methodology_critical_warning_count $methodology_critical
close $facts

close_project
