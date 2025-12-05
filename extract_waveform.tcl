# Vivado XSim Waveform Extractor
#
# Extracts simulation waveform data from Vivado XSim to VCD format.
# Works with testbenches and manual signal forcing.
#
# Usage:
#   1. Run simulation in Vivado
#   2. Tools -> Run Tcl Script -> select this file
#   3. Use capture command (see below)
#
# Author: Ross
# License: MIT

# ----- Configuration -----
# Output goes to 'vcd_output' folder in the script's directory
set ::script_dir [file dirname [info script]]
set ::output_dir [file join $::script_dir "vcd_output"]
set ::force_commands {}

# Ensure output directory exists
proc ensure_output_dir {} {
    if {![file exists $::output_dir]} {
        file mkdir $::output_dir
        puts "Created output folder: $::output_dir"
    }
}

# Set output directory (optional override)
proc set_output_dir {path} {
    set ::output_dir $path
    ensure_output_dir
    puts "Output: $path"
}

# Build output path
proc outpath {filename} {
    ensure_output_dir
    return [file join $::output_dir $filename]
}

# ----- Force Signal Commands -----
# Records forces so they can be replayed after restart

# Add a force (remembered for replay)
# Usage: force /test/clk bin 0
#        force /test/data hex FF
proc force {signal radix value} {
    lappend ::force_commands [list $signal $radix $value]
    add_force $signal -radix $radix [list $value 0ns]
    puts "  $signal = $value ($radix)"
}

# Clear all recorded forces
proc clear_forces {} {
    set ::force_commands {}
    puts "Forces cleared"
}

# List recorded forces
proc show_forces {} {
    if {[llength $::force_commands] == 0} {
        puts "No forces recorded"
        return
    }
    puts "Recorded forces:"
    foreach f $::force_commands {
        lassign $f sig radix val
        puts "  $sig = $val ($radix)"
    }
}

# Apply all recorded forces (internal use)
proc replay_forces {} {
    foreach f $::force_commands {
        lassign $f sig radix val
        catch {add_force $sig -radix $radix [list $val 0ns]}
    }
}

# ----- Main Capture Function -----
# Restarts simulation, applies forces, runs, and saves VCD
#
# Usage:
#   capture "50us"              - run for 50 microseconds
#   capture "1ms" "mytest"      - custom filename
#   capture "all"               - testbench mode (run until $finish)

proc capture {{run_time "all"} {filename "waveform"}} {
    set vcd_file [outpath "${filename}.vcd"]
    
    puts ""
    puts "Capturing waveform..."
    puts "  Output: $vcd_file"
    puts "  Duration: $run_time"
    
    # Restart to time 0
    catch {restart}
    
    # Apply forces at time 0
    if {[llength $::force_commands] > 0} {
        puts "  Applying [llength $::force_commands] force(s)"
        replay_forces
    }
    
    # Start VCD capture
    if {[catch {open_vcd $vcd_file} err]} {
        puts "ERROR: $err"
        return ""
    }
    catch {log_vcd *}
    
    # Run simulation
    if {$run_time eq "all"} {
        catch {run -all}
    } else {
        catch {run $run_time}
    }
    
    # Save and close
    catch {close_vcd}
    
    puts ""
    puts "Done. Saved to: $vcd_file"
    puts "Simulation ended at: [current_time]"
    puts ""
    
    return $vcd_file
}

# ----- Utility Commands -----

# List all signals in design
proc signals {} {
    set sigs [get_objects]
    foreach sig $sigs {
        set name [get_property NAME $sig]
        set type [get_property TYPE $sig]
        catch {set val [get_value $sig]} val
        puts "  $name = $val ($type)"
    }
    puts "Total: [llength $sigs] signals"
}

# Export current values to CSV (no restart)
proc snapshot {{filename "snapshot.csv"}} {
    set outfile [outpath $filename]
    set fp [open $outfile w]
    set sigs [get_objects]
    
    puts $fp "Signal,Value,Type"
    foreach sig $sigs {
        set name [get_property NAME $sig]
        set type [get_property TYPE $sig]
        catch {set value [get_value $sig]} value
        puts $fp "$name,$value,$type"
    }
    
    close $fp
    puts "Saved: $outfile"
}

# Show help
proc help {} {
    puts ""
    puts "Vivado Waveform Extractor"
    puts ""
    puts "Capture:"
    puts "  capture \"50us\"           - capture for 50us"
    puts "  capture \"all\"            - run testbench until \$finish"
    puts "  capture \"1ms\" \"myfile\"   - custom duration and filename"
    puts ""
    puts "Force signals:"
    puts "  force /path/sig hex FF   - force hex value"
    puts "  force /path/sig bin 1010 - force binary value"
    puts "  show_forces              - list recorded forces"
    puts "  clear_forces             - clear all forces"
    puts ""
    puts "Utility:"
    puts "  signals                  - list all signals"
    puts "  snapshot                 - save current values to CSV"
    puts "  set_output_dir \"path\"    - set output directory"
    puts ""
}

# ----- Startup -----
puts ""
puts "Waveform Extractor loaded. Type 'help' for commands."
puts ""
