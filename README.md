<!--
PROJECT BANNER PLACEHOLDER

Recommended file: images/banner.png

After adding it, replace this comment with:

<p align="center">
  <img src="images/banner.png" alt="Vivado WDB Waveform Converter" width="900">
</p>
-->

# Vivado WDB Waveform Converter

Convert AMD Vivado/XSim **WDB and WCFG waveform databases directly to VCD, CSV, JSON and Excel** without rerunning the simulation.

The converter also handles VCD-to-CSV/JSON/Excel workflows, batch conversion, signal filtering, per-signal radix selection, SystemVerilog and VHDL waveform types, and standalone Windows builds.

## Supported conversions

| Input | VCD | CSV | JSON | Excel |
|---|:---:|:---:|:---:|:---:|
| WDB | Yes | Yes | Yes | Yes |
| WDB + WCFG | Yes | Yes | Yes | Yes |
| WCFG | Yes | Yes | Yes | Yes |
| VCD | - | Yes | Yes | Yes |

WDB/WCFG input defaults to **VCD**. VCD input defaults to **CSV**.

## Features

- Native Vivado/XSim `.wdb` decoding
- Optional `.wcfg` signal-selection and radix metadata
- VCD, CSV, JSON and Excel export
- Multiple-file batch conversion
- Automatic unambiguous WDB/WCFG pairing
- Full hierarchical signal names
- Right-click per-signal radix selection
- WCFG-derived radix defaults
- Wide vectors and X/Z state preservation
- SystemVerilog `real`
- Packed and unpacked arrays
- Multidimensional arrays
- VHDL scalar, vector, array, record, integer, time and real types
- Mixed SystemVerilog/VHDL simulations
- Background GUI conversion
- CLI and GUI operation
- Standalone Windows executable build

<!--
MAIN GUI SCREENSHOT PLACEHOLDER

Recommended file: images/gui-v2.png

After adding it:
![Vivado WDB Waveform Converter GUI](images/gui-v2.png)
-->

## Windows standalone executable

Run:

    BUILD_WINDOWS_EXE.bat

The builder creates a one-file Windows executable with Python, Tkinter and Excel support bundled inside it.

Output:

    release\VivadoWDBWaveformConverter-v2.0.1.exe

Release archive:

    VivadoWDBWaveformConverter-v2.0.1-Windows-x64.zip

The target computer does not need Python installed.

### Default output location

When running the standalone executable, conversions are written by default to:

    <folder containing the EXE>\converted_output\

The converter does not use the PyInstaller/AppData temporary extraction directory for user output.

When running directly from source, the default `converted_output` folder is beside `waveform_converter.py`.

## Quick start

### WDB to VCD

    python waveform_converter.py simulation.wdb

or explicitly:

    python waveform_converter.py simulation.wdb --vcd

### WDB + WCFG

    python waveform_converter.py simulation.wdb simulation.wcfg --vcd

A WCFG can also be supplied directly when its associated WDB can be resolved:

    python waveform_converter.py simulation.wcfg --vcd

### Other formats

    python waveform_converter.py simulation.wdb --csv
    python waveform_converter.py simulation.wdb --json
    python waveform_converter.py simulation.wdb --excel

Existing VCD files:

    python waveform_converter.py waveform.vcd --csv
    python waveform_converter.py waveform.vcd --json
    python waveform_converter.py waveform.vcd --excel

## Batch conversion

Multiple WDB and WCFG files can be selected at once from the GUI.

Command-line example:

    python waveform_converter.py run1.wdb run1.wcfg run2.wdb run2.wcfg --vcd

The converter pairs WCFG files with WDB files only when the mapping is unambiguous.

<!--
BATCH CONVERSION SCREENSHOT PLACEHOLDER

Recommended file: images/batch-conversion.png

After adding it:
![Batch conversion](images/batch-conversion.png)
-->

## Signal selection and radix

List signals:

    python waveform_converter.py simulation.wdb --signals

Filter signals:

    python waveform_converter.py simulation.wdb --csv --include "*data*" --exclude "*internal*"

In the GUI, right-click one or more highlighted signals to select the radix. Available formats include binary, octal, hexadecimal, unsigned decimal, signed decimal and signed magnitude. `Default / WCFG` returns the signal to its WCFG/default setting.

Radix affects CSV, JSON and Excel presentation. VCD remains standards-compliant and radix-neutral.

<!--
RADIX MENU SCREENSHOT PLACEHOLDER

Recommended file: images/radix-menu.png

After adding it:
![Signal radix menu](images/radix-menu.png)
-->

## Native WDB reader

The characterized WDB profile currently targets databases containing:

    Xilinx WAVE DATABASE 01
    Xilinx ISim DBG 006

The reader uses embedded waveform event data, debug metadata and runtime type information. Unsupported or ambiguous structures are rejected instead of being guessed.

See `WDB_FORMAT_NOTES.md` for format details.

## Live Vivado VCD capture

`extract_waveform.tcl` remains available for users who prefer live VCD recording from XSim.

With an active simulation:

    Tools -> Run Tcl Script -> extract_waveform.tcl

Direct WDB conversion does not require the Tcl helper and does not rerun the simulation.

## Running from source

Python 3.10 or newer is recommended.

Install dependencies:

    python -m pip install -r requirements.txt

Launch the GUI:

    python waveform_converter.py

or:

    pythonw waveform_converter.pyw

## Project structure

    Vivado-WDB-Waveform-Converter/
    |
    |-- waveform_converter.py
    |-- waveform_converter.pyw
    |-- vcd_converter.py
    |-- vcd_converter.pyw
    |-- CONVERT_WAVEFORM.bat
    |-- LIST_SIGNALS.bat
    |-- BUILD_WINDOWS_EXE.bat
    |-- extract_waveform.tcl
    |-- WDB_FORMAT_NOTES.md
    |-- CHANGELOG.md
    |-- requirements.txt
    |-- LICENSE
    |
    `-- images/
        |-- README.md
        |-- banner.png
        |-- gui-v2.png
        |-- radix-menu.png
        `-- batch-conversion.png

The image filenames above are placeholders for the current release screenshots.

## Legacy compatibility

The original `vcd_converter.py` and `vcd_converter.pyw` entry points remain available for existing VCD conversion workflows.

## License

MIT License. See `LICENSE`.
