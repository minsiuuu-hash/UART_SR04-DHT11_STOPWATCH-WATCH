# Run from a separate build directory with Vivado 2023.2:
# vivado -mode batch -source /path/to/Verification_Code/synth_external_sync.tcl
set repo_dir [file normalize [file join [file dirname [info script]] ..]]
read_verilog [glob [file join $repo_dir Code *.v]]
synth_design -top TOP_module -part xc7a35tcpg236-1

# 6 switches + 4 buttons + UART RX + SR04 echo + DHT input = 13 chains.
# Check that synthesis preserved two marked flip-flops per chain.
set sync_cells [get_cells -hier -filter {ASYNC_REG == TRUE}]
if {[llength $sync_cells] != 26} {
    error "Expected 26 ASYNC_REG flip-flops, found [llength $sync_cells]"
}
foreach cell $sync_cells {
    if {![string match FD* [get_property REF_NAME $cell]]} {
        error "Synchronizer was not implemented as a flip-flop: $cell"
    }
}
report_utilization -file sync_utilization.rpt
puts "PASS SYNTH: 13 synchronizer chains / 26 ASYNC_REG flip-flops preserved"
exit
