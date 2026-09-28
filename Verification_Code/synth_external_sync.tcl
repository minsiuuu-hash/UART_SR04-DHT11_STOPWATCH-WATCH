# Run from a separate build directory with Vivado 2023.2:
# vivado -mode batch -source /path/to/Verification_Code/synth_external_sync.tcl
set repo_dir [file normalize [file join [file dirname [info script]] ..]]
read_verilog [glob [file join $repo_dir Code *.v]]
synth_design -top TOP_module -part xc7a35tcpg236-1

# 6 switches + 4 buttons + UART RX + SR04 echo + DHT input = 13 chains.
# Check the inferred registers by name, without relying on synthesis attributes.
set sync_cells [get_cells -hier -regexp {(.*/)?(meta_ff_reg|sync_ff_reg)$}]
if {[llength $sync_cells] != 26} {
    error "Expected 26 synchronizer flip-flops, found [llength $sync_cells]"
}
foreach cell $sync_cells {
    if {![string match FD* [get_property REF_NAME $cell]]} {
        error "Synchronizer was not implemented as a flip-flop: $cell"
    }
}
report_utilization -file sync_utilization.rpt
puts "PASS SYNTH: 13 synchronizer chains / 26 flip-flops preserved"
exit
