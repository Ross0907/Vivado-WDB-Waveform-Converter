# Vivado Waveform Extractor

Extract simulation waveform data from Xilinx Vivado XSim to VCD, CSV, JSON, or Excel formats.

## Quick Start

### 1. Generate VCD from Vivado

In Vivado: `Tools` → `Run Tcl Script` → select `extract_waveform.tcl` (while simulation window is open)

```tcl
capture "all"          # For testbench (runs until $finish)
capture "100us"        # For manual testing
```

The VCD file is saved to `vcd_output/` next to the script.

### 2. Convert VCD to Other Formats (Optional)

```bash
python vcd_converter.py                      # GUI
python vcd_converter.py waveform.vcd --json  # CLI
```

![VCD Converter GUI](images/gui_screenshot.png)

## Requirements

**Tcl Script:** Xilinx Vivado 2020.x+ with active XSim simulation

**Python Converter:** Python 3.6+ (tkinter included). Excel export auto-installs `openpyxl` on first use.

## Project Structure

```
├── extract_waveform.tcl    # Tcl script for Vivado XSim
├── vcd_converter.py        # Python converter (CLI + GUI)
├── vcd_converter.pyw       # GUI only (double-click, no console window)
├── vcd_output/             # VCD files (auto-created)
└── converted_output/       # CSV/JSON/Excel (auto-created)
```

---

## Command Reference

### Tcl Commands (Vivado)

| Command | Description |
|---------|-------------|
| `capture "time"` | Restart, apply forces, run, save VCD |
| `capture "all"` | Run until testbench `$finish` |
| `force /path hex FF` | Force signal (remembered across restarts) |
| `show_forces` | List recorded forces |
| `clear_forces` | Clear all forces |
| `signals` | List all signals |
| `snapshot` | Export current values to CSV |

### Python CLI

```
python vcd_converter.py <input.vcd> [-o output] [--csv|--json|--excel] [--hex|--int|--signed|--smag|--bin] [--us|--ns|--ps]
```

| Option | Description |
|--------|-------------|
| `-o <file>` | Output path |
| `--csv/--json/--excel` | Output format (default: csv) |
| `--hex` | Values as hexadecimal (default) |
| `--int` | Values as unsigned integers |
| `--signed` | Values as signed two's complement |
| `--smag` | Values as signed magnitude |
| `--bin` | Values as binary strings |
| `--us/--ns/--ps` | Time unit (default: us) |

> **Excel Graphing Tip:** Use `--int`, `--signed`, or `--smag` for Excel export if you want to create graphs. These formats store actual numbers. Hex and binary are stored as text (to preserve formatting like leading zeros) and cannot be graphed directly.

---

## Theory & Implementation Details

### Why VCD?

Vivado's XSim simulator stores waveform data internally but doesn't provide direct export to common formats. The simulator does support **VCD (Value Change Dump)**, an IEEE standard (IEEE 1364) originally designed for Verilog simulators.

VCD is event-driven: it only records timestamps when signals *change*, making it compact. This is fundamentally different from sampling at fixed intervals.

### How the Tcl Script Works

The script leverages three undocumented/lesser-known XSim Tcl commands:

#### 1. `open_vcd <filename>`
Opens a VCD file for writing. XSim will write the VCD header (date, version, timescale, signal declarations) immediately.

#### 2. `log_vcd <signals>`
Registers signals to be logged. The wildcard `*` captures all signals in the current scope. This command tells XSim: "whenever these signals change during simulation, write the new value to the VCD file."

**Critical detail:** `log_vcd` must be called *before* running simulation. It sets up listeners on the signals—it doesn't retroactively capture past changes.

#### 3. `close_vcd`
Flushes buffers and finalizes the VCD file. Without this, the file may be truncated or corrupted.

#### The Capture Flow

```
capture "100us"
    │
    ├─→ restart              # Reset simulation to time 0
    │                        # (Required: log_vcd only works from current time forward)
    │
    ├─→ replay_forces        # Re-apply any forces (they're lost on restart)
    │
    ├─→ open_vcd "file.vcd"  # Start VCD recording
    │
    ├─→ log_vcd *            # Register all signals for logging
    │
    ├─→ run 100us            # Advance simulation (VCD records changes)
    │   or run -all          # Run until $finish/$stop
    │
    └─→ close_vcd            # Finalize file
```

#### Force Replay Mechanism

When you call `force /tb/sig hex FF`, two things happen:
1. The force is applied immediately via Vivado's `add_force` command
2. The force is stored in a Tcl list: `lappend ::force_commands [list $signal $radix $value]`

On `capture`, the simulation restarts (time = 0), which clears all forces. The script then iterates through `::force_commands` and reapplies each one before running.

### VCD File Format Deep Dive

#### Header Section

```
$date
   Fri Dec 06 10:30:00 2025
$end
$version
   Vivado Simulator 2025.2
$end
$timescale
   1ps                        ← All timestamps are in picoseconds
$end
```

#### Variable Declarations

```
$scope module testbench $end
   $var wire 1 ! clk $end     ← 1-bit wire, ID='!', name='clk'
   $var wire 8 " data [7:0] $end  ← 8-bit wire, ID='"', name='data'
   $var reg 4 # count [3:0] $end  ← 4-bit reg, ID='#', name='count'
$upscope $end
$enddefinitions $end
```

The single-character IDs (`!`, `"`, `#`, `$`, `%`, etc.) are short identifiers assigned by the simulator. They map to the full signal names and are used in the value change section for compactness.

#### Value Changes

```
#0                    ← Time = 0 ps
0!                    ← clk = 0 (single-bit: value immediately before ID)
b00000000 "           ← data = 00000000 (multi-bit: 'b' prefix, space, then ID)
b0000 #               ← count = 0000

#5000                 ← Time = 5000 ps = 5 ns
1!                    ← clk = 1

#10000                ← Time = 10000 ps = 10 ns
0!                    ← clk = 0
b00000001 "           ← data = 00000001
```

**Format rules:**
- Timestamps: `#<integer>` (in timescale units)
- Single-bit: `<0|1|x|z><id>` (no space)
- Multi-bit: `b<binary> <id>` (space required)
- Unknown: `x` (unknown/uninitialized)
- High-Z: `z` (high impedance/tri-state)

### Python Parser Implementation

#### Pass 1: Header Parsing

Extract signal declarations using regex:

```python
pattern = r'\$var\s+(\w+)\s+(\d+)\s+(\S+)\s+(\w+)(?:\s+\[[\d:]+\])?\s+\$end'
#              │       │       │       │           │
#              │       │       │       │           └─ Optional bit range [7:0]
#              │       │       │       └─ Signal name
#              │       │       └─ Short ID (!, ", #, etc.)
#              │       └─ Bit width
#              └─ Type (wire, reg, integer)
```

This builds a dictionary mapping IDs to signal metadata:
```python
signals = {
    '!': {'name': 'clk', 'width': 1, 'type': 'wire'},
    '"': {'name': 'data', 'width': 8, 'type': 'wire'},
    ...
}
```

#### Pass 2: Value Change Parsing

Scan line by line:

```python
for line in content.split('\n'):
    if line.startswith('#'):
        current_time = int(line[1:])      # Extract timestamp
    elif line.startswith('b'):
        # Multi-bit: "b01010101 !"
        match = re.match(r'b([01xXzZ]+)\s+(\S+)', line)
        value, var_id = match.groups()
        changes.append((current_time, var_id, value))
    elif line[0] in '01xXzZ':
        # Single-bit: "1!" or "0!"
        var_id = line[1:]
        changes.append((current_time, var_id, line[0]))
```

#### Timeline Construction

VCD only records *changes*. To get values at any timestamp, we need to track state:

```python
current_values = {vid: '0' for vid in signals}  # Initialize all to 0
rows = []

for timestamp in sorted(timestamps):
    # Apply all changes at this timestamp
    for t, vid, val in changes:
        if t == timestamp:
            current_values[vid] = val
    
    # Record snapshot of all values at this moment
    rows.append((timestamp, dict(current_values)))
```

This produces a table where each row has the complete state of all signals at that timestamp.

#### Time Unit Conversion

VCD timestamps are in the timescale unit (picoseconds for Vivado):

```python
# Convert picoseconds to user-requested unit
divisors = {
    'ps': 1,           # 1 ps = 1 ps
    'ns': 1000,        # 1 ns = 1000 ps
    'us': 1000000,     # 1 μs = 1,000,000 ps
    'ms': 1000000000   # 1 ms = 1,000,000,000 ps
}
time_in_unit = timestamp_ps / divisors[unit]
```

#### Value Formatting

Binary strings from VCD need conversion:

```python
def format_value(binary_str, fmt):
    if 'x' in binary_str.lower() or 'z' in binary_str.lower():
        return binary_str  # Can't convert unknown/high-z
    
    decimal = int(binary_str, 2)  # Binary string → integer
    
    if fmt == 'hex':
        return format(decimal, 'X')  # → "A", "FF", "DEADBEEF"
    elif fmt == 'int':
        return str(decimal)          # → "10", "255", "3735928559"
    else:
        return binary_str            # Keep as binary
```

---

## Troubleshooting

**No signals in VCD:** Run simulation at least once before loading the script. The design must be elaborated.

**Empty VCD file:** Ensure simulation ran (`capture` prints end time). Check write permissions.

**Forces not applied:** Signal paths must be exact. Use `signals` to see available paths. Format: `/testbench/instance/signal`

**Excel export fails:** Install openpyxl: `pip install openpyxl`

## License

MIT
