# Vivado XSim Waveform Extractor
# Extracts simulation waveforms to VCD format
# Usage: Tools -> Run Tcl Script -> select this file
# Author: Ross | License: MIT

# ----- Configuration -----
set ::script_dir [file dirname [info script]]
set ::output_dir [file join $::script_dir "vcd_output"]
set ::force_commands {}
set ::auto_log_enabled 1
set ::vcd_is_open 0
set ::auto_log_file "waveform.vcd"

proc ensure_output_dir {} {
    if {![file exists $::output_dir]} {
        file mkdir $::output_dir
    }
}

proc outpath {filename} {
    ensure_output_dir
    return [file join $::output_dir $filename]
}

# ----- Force Commands -----
proc force {signal radix value} {
    lappend ::force_commands [list $signal $radix $value]
    add_force $signal -radix $radix [list $value 0ns]
}

proc clear_forces {} {
    set ::force_commands {}
}

proc show_forces {} {
    if {[llength $::force_commands] == 0} {
        puts "No forces recorded"
        return
    }
    foreach f $::force_commands {
        lassign $f sig radix val
        puts "  $sig = $val ($radix)"
    }
}

proc replay_forces {} {
    foreach f $::force_commands {
        lassign $f sig radix val
        catch {add_force $sig -radix $radix [list $val 0ns]}
    }
}

# ----- Auto-Logging -----
proc start_auto_log {{filename ""}} {
    if {$::vcd_is_open} { return }
    if {$filename eq ""} { set filename $::auto_log_file }
    set vcd_path [outpath $filename]
    if {[catch {open_vcd $vcd_path} err]} { return }
    catch {log_vcd *}
    set ::vcd_is_open 1
    puts "Recording: $vcd_path"
}

proc stop_auto_log {} {
    if {$::vcd_is_open} {
        catch {close_vcd}
        set ::vcd_is_open 0
        puts "Saved: [outpath $::auto_log_file]"
    }
}

proc autolog {{state ""}} {
    if {$state eq ""} {
        puts "Auto-logging: [expr {$::auto_log_enabled ? {ON} : {OFF}}]"
        return
    }
    if {$state eq "on" || $state eq "1"} {
        set ::auto_log_enabled 1
    } elseif {$state eq "off" || $state eq "0"} {
        set ::auto_log_enabled 0
        stop_auto_log
    }
}

rename run _original_run
proc run {args} {
    if {$::auto_log_enabled && !$::vcd_is_open} { start_auto_log }
    uplevel 1 _original_run $args
}

rename restart _original_restart
proc restart {args} {
    stop_auto_log
    uplevel 1 _original_restart $args
}

# ----- Capture Function -----
proc capture {{run_time "all"} {filename "waveform"}} {
    set vcd_file [outpath "${filename}.vcd"]
    
    catch {restart}
    if {[llength $::force_commands] > 0} { replay_forces }
    
    if {[catch {open_vcd $vcd_file} err]} {
        puts "ERROR: $err"
        return ""
    }
    catch {log_vcd *}
    
    if {$run_time eq "all"} {
        catch {run -all}
    } else {
        catch {run $run_time}
    }
    
    catch {close_vcd}
    puts "Saved: $vcd_file (ended at [current_time])"
    return $vcd_file
}

# ----- Utilities -----
proc signals {} {
    set sigs [get_objects]
    foreach sig $sigs {
        set name [get_property NAME $sig]
        catch {set val [get_value $sig]} val
        puts "  $name = $val"
    }
    puts "Total: [llength $sigs] signals"
}

proc snapshot {{filename "snapshot.csv"}} {
    set outfile [outpath $filename]
    set fp [open $outfile w]
    puts $fp "Signal,Value,Type"
    foreach sig [get_objects] {
        set name [get_property NAME $sig]
        set type [get_property TYPE $sig]
        catch {set value [get_value $sig]} value
        puts $fp "$name,$value,$type"
    }
    close $fp
    puts "Saved: $outfile"
}

proc help {} {
    puts "
Waveform Extractor Commands:
  capture \"50us\"         - restart + capture for duration
  capture \"all\"          - run until $finish
  autolog on/off         - toggle auto-logging
  stop_auto_log          - save current VCD
  force /path hex FF     - force signal value
  show_forces            - list forces
  clear_forces           - clear forces
  signals                - list all signals
  snapshot               - export values to CSV
"
}

puts "Waveform Extractor loaded (auto-logging ON). Type 'help' for commands."
