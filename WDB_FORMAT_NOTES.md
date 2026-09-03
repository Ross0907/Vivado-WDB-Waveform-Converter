# XSim WDB binary format notes

This document describes the WDB profile implemented by `waveform_converter.py`.

The implementation is based on observed Vivado/XSim 2026.1 waveform databases. WDB is a proprietary format; this document is not an AMD format specification.

## Compatibility profile

Accepted database signature:

```text
Xilinx WAVE DATABASE 01\0
```

Required embedded debug database:

```text
Xilinx ISim DBG 006\0
```

The 64-bit section pointers in the WDB header identify the RTTI, DBG, and `WDB.Event` sections. The reader validates these sections rather than inferring unknown top-level layouts.

## Event index pages

Each event root is represented by a linked page list. The supported page size is `0x4C0` bytes.

Relevant fields:

```text
+0x000  uint64  next page pointer
+0x008  uint64  compressed payload pointer[100]
+0x328  uint32  compressed payload size[100]
+0x4B8  uint32  valid payload count
```

Compressed payloads are zlib streams. The reader validates page boundaries, payload ranges, record counts, and continuation cycles.

## Decompressed chunks

Each payload begins with a 20-byte chunk header:

```text
uint64 start_time
uint64 end_time
uint32 record_count
```

Each event has a 16-byte fixed header followed by a variable payload:

```text
uint32 time_lo
uint32 time_hi
uint32 storage_id
uint32 payload_bytes
uint8  payload[payload_bytes]
```

Timestamp:

```text
time = time_lo | (time_hi << 32)
```

The supported XSim files use 1 ps WDB event ticks.

## SystemVerilog digital values

Digital payloads use groups of 8 bytes per 32 stored bits:

```text
uint32 aval
uint32 bval
```

Per bit:

```text
aval bval
 0    0   -> 0
 1    0   -> 1
 1    1   -> X
 0    1   -> Z
```

Variable payload sizes support vectors wider than 32 bits. High unused bits in the final storage word are masked to the declared DBG width.

## Real values

SystemVerilog `real` and supported VHDL `REAL` waveforms use little-endian IEEE-754 binary64 storage. VCD output uses standard `r...` value changes.

## Chunk snapshots

XSim chunks may begin with state records that repeat the current value. The converter orders records, normalizes them to the declared object representation, collapses repeated snapshots, and keeps the final settled state for each physical timestamp.

## Embedded DBG database

The embedded DBG database supplies hierarchy, HDL object names, declared widths, type information, runtime addresses, aliases, parameters/constants, and object ranges.

Supported record sizes are:

```text
structure record   36 bytes
object record      44 bytes
allocation record  56 bytes
```

A waveform stream is not assigned a name until its runtime storage maps uniquely to compatible DBG/RTTI metadata.

## Runtime event banks

Event roots use local `storage_id` values while DBG objects use absolute runtime addresses:

```text
absolute_address = bank_base + storage_id
```

The normal bank size for the supported profile is `0x800`, with metadata used where available. Root-to-bank assignments must resolve uniquely. WCFG selection can disambiguate only when it identifies one unique valid assignment.

## WCFG

WCFG is configuration metadata rather than waveform sample storage.

The converter uses WCFG for:

- referenced WDB path resolution;
- initial signal selection;
- supported display metadata;
- radix defaults.

Recognized radix values include hexadecimal, unsigned decimal, signed decimal, binary, and octal forms. WCFG names do not override DBG names or widths.

## Partial event fragments

`storage_id` is an address within the resolved runtime bank. XSim can write full snapshots followed by shorter updates inside the same DBG allocation. The converter resolves each fragment to a unique containing allocation, merges it into the current storage image, and only then decodes the logical waveform value.

## VHDL storage

The storage representation is selected per mapped RTTI type, allowing VHDL and SystemVerilog objects to coexist in one WDB.

Supported VHDL forms include:

- `STD_LOGIC` / `STD_ULOGIC`;
- `STD_LOGIC_VECTOR`, `STD_ULOGIC_VECTOR`, `SIGNED`, `UNSIGNED`;
- `BIT`, `BIT_VECTOR`, `BOOLEAN`;
- `INTEGER`, `NATURAL`, `POSITIVE`;
- `TIME`;
- `REAL`;
- user-defined enumerations;
- records;
- one-dimensional and multidimensional arrays.

Representable record fields and array elements are exposed as ordinary waveform leaves. SystemVerilog unpacked arrays are handled through the same recursive type/range model, including multidimensional arrays and arrays of `real`.

## Error policy

Conversion stops when required structural relationships cannot be established, including:

- unsupported WDB or DBG signature;
- unknown top-level section layout;
- invalid event pages or compressed payloads;
- inconsistent event storage shapes;
- no compatible DBG runtime bank;
- unresolved multiple bank assignments;
- conflicting alias width/type metadata;
- unsupported nested storage types.

A decoding failure produces an error and diagnostic log rather than guessed signal names or values.
