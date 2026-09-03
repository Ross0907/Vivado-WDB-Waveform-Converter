#!/usr/bin/env python3
"""Compatibility launcher for existing vcd_converter.py commands."""
from __future__ import annotations
import sys
from waveform_converter import cli_main

if __name__ == "__main__":
    args = sys.argv[1:]
    value_flags = {"--auto", "--hex", "--int", "--unsigned", "--signed", "--smag", "--bin", "--oct"}
    if args and not any(a in value_flags for a in args):
        # Preserve the original vcd_converter.py table default.
        args.append("--hex")
    raise SystemExit(cli_main(args))
