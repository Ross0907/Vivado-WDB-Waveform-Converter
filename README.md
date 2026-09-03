# Vivado Waveform Converter

Vivado Waveform Converter is a waveform conversion and inspection utility for AMD Vivado/XSim simulation data.

Version 2.0.0 adds direct WDB/WCFG support to the original VCD conversion workflow. Existing XSim waveform databases can be converted without reopening or rerunning the simulation in Vivado.

## Features

- WDB to VCD, CSV, JSON, or Excel
- WDB + WCFG to VCD, CSV, JSON, or Excel
- WCFG-only input when the referenced WDB can be resolved
- VCD to CSV, JSON, or Excel
- Windows GUI and command-line interface
- Multi-file WDB/WCFG batch conversion
- Per-signal radix selection from the signal-table right-click menu
- WCFG-derived signal selection and radix defaults
- SystemVerilog and VHDL waveform handling within the supported WDB profile
- 0/1/X/Z states, real values, aliases, wide vectors, partial updates, arrays, records, and mixed-language designs
- Structural validation of WDB/DBG/RTTI data before conversion

VCD-to-VCD conversion is intentionally omitted.

## Windows release

The standalone Windows executable is built from this repository with:

```text
BUILD_WINDOWS_EXE.bat
```

The builder creates:

```text
release\VivadoWaveformConverter-v2.0.0.exe
VivadoWaveformConverter-v2.0.0-Windows-x64.zip
```

The finished EXE bundles the Python runtime, Tkinter, and Excel support. Python is required only to build the executable, not to run it.

## Running from source

Python 3.10 or newer is required.

Install the optional Excel dependency:

```powershell
py -3 -m pip install -r requirements.txt
```

Start the GUI:

```powershell
py -3 waveform_converter.py --gui
```

Or double-click:

```text
waveform_converter.pyw
```

## GUI usage

Source files load automatically after selection.

- WDB/WCFG input defaults to VCD output.
- VCD input defaults to CSV output.
- The signal table shows the signals selected for export.
- Use **Select...** to change the selection.
- Highlight one or more signals, right-click, and use **Radix** to change their table/export formatting.
- **Default / WCFG** clears a per-signal radix override.
- Decode and export operations run on background workers so the GUI remains responsive.
- Successful conversion is reported in the status bar rather than a modal dialog.

Radix affects CSV, JSON, Excel, and the GUI table. Standard VCD does not define display-radix metadata, so VCD output remains radix-neutral.

## Batch conversion

The normal file selectors support multiple files.

- Select multiple WDB files in the Waveform browser.
- Select matching WCFG files together when required.
- Pairing uses the WCFG database reference first and matching filename stem second.
- Ambiguous or unmatched WCFG pairings are rejected.
- The first batch item is used for the signal-table preview.
- The Output field becomes an output-folder field in batch mode.
- A `batch_conversion_report.txt` file is written for each batch.

CLI example:

```powershell
py -3 waveform_converter.py a.wdb a.wcfg b.wdb b.wcfg --vcd -o converted_output
```

## Command line examples

WDB to VCD using the default output format:

```powershell
py -3 waveform_converter.py simulation.wdb
```

WDB + WCFG to CSV:

```powershell
py -3 waveform_converter.py simulation.wdb simulation.wcfg --csv
```

WCFG-only input:

```powershell
py -3 waveform_converter.py simulation.wcfg --json
```

VCD to CSV using the default output format:

```powershell
py -3 waveform_converter.py waveform.vcd
```

Excel export:

```powershell
py -3 waveform_converter.py waveform.vcd --excel --signed
```

List WDB declarations:

```powershell
py -3 waveform_converter.py simulation.wdb simulation.wcfg --signals
```

Export all stored WDB declarations instead of the WCFG selection:

```powershell
py -3 waveform_converter.py simulation.wdb simulation.wcfg --csv --all-stored
```

Per-signal radix rules:

```powershell
py -3 waveform_converter.py simulation.wdb --csv ^
  --radix "*counter*=unsigned" ^
  --radix "*signed*=signed" ^
  --radix "*opcode*=hex"
```

Compact event-oriented JSON:

```powershell
py -3 waveform_converter.py simulation.wdb --json --json-events
```

Common options:

```text
--vcd / --csv / --json / --excel
--format vcd|csv|json|excel
-o PATH
--auto / --hex / --int / --signed / --bin / --oct / --smag
--radix PATTERN=RADIX
--fs / --ps / --ns / --us / --ms
--timescale 1ps
--signals
--include PATTERN
--exclude PATTERN
--primary-only
--all-stored
--json-events
--wcfg FILE
--gui
```

`--timescale` applies to WDB/WCFG-to-VCD output. A coarser VCD timescale is rejected when recorded timestamps cannot be represented exactly.

## WCFG behavior

WCFG is optional configuration metadata; waveform samples remain in the WDB.

With WDB-only input, the converter obtains stored samples, signal names, hierarchy, widths, types, and aliases from the WDB and its embedded debug/type metadata.

When WCFG is supplied, it supplies initial signal selection and supported display metadata such as radix. WCFG data does not override exact WDB names or declared widths.

## WDB compatibility

The direct reader targets this format profile:

```text
Xilinx WAVE DATABASE 01
Xilinx ISim DBG 006
```

The decoder validates the container, DBG/RTTI metadata, event pages, compressed chunks, runtime-bank mapping, widths/types, and aliases. Unsupported or ambiguous structures stop with a diagnostic instead of producing guessed waveform data.

The WDB reader does not launch Vivado, rerun a testbench, or modify the input WDB/WCFG.

See `WDB_FORMAT_NOTES.md` for implementation details and format boundaries.

## Diagnostics

For WDB input the converter writes a diagnostic log beside the output:

```text
<output-file>.wdbdecode.log
```

Keep this log when reporting an unsupported WDB or compatibility issue.

## Live XSim capture

`extract_waveform.tcl` remains available for simulations that are still running inside Vivado. It uses XSim's standard VCD logging commands and is independent of the direct WDB reader.

## Compatibility entry points

`vcd_converter.py` and `vcd_converter.pyw` are retained so existing VCD converter workflows continue to work through the unified engine.

## Repository files

```text
waveform_converter.py        converter engine, CLI, and GUI
waveform_converter.pyw       Python GUI launcher
vcd_converter.py             compatibility CLI launcher
vcd_converter.pyw            compatibility GUI launcher
CONVERT_WAVEFORM.bat         Windows script/drag-and-drop launcher
LIST_SIGNALS.bat             Windows signal-list helper
BUILD_WINDOWS_EXE.bat        standalone Windows EXE builder
extract_waveform.tcl         optional live XSim capture helper
WDB_FORMAT_NOTES.md          WDB/DBG/RTTI format documentation
requirements.txt             Excel export dependency
CHANGELOG.md                 release history
LICENSE                      MIT license
```

## License

MIT. See `LICENSE`.
