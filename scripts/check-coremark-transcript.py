#!/usr/bin/env python3
"""Oracle for the CPU-driven CoreMark UART transcript.

The score itself is only meaningful on the board, so this checks what a
single-iteration RTL run can prove: CoreMark's own CRCs, which do not depend on
the iteration count, and that the run reached the port's final line.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

# seed1=0, seed2=0, seed3=0x66, size 666 per algorithm (TOTAL_DATA_SIZE 2000
# divided across the three algorithms), which core_main.c calls known_id 3.
EXPECTED_SEEDCRC = 0xE9F5
EXPECTED_CRC = {"list": 0xE714, "matrix": 0x1FD7, "state": 0x8E3A}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("transcript", type=Path)
    args = parser.parse_args()

    text = args.transcript.read_bytes().decode("ascii").replace("\r", "")

    for line in text.splitlines():
        if line.startswith("ERROR!") or "]ERROR!" in line:
            # A short simulated run cannot satisfy CoreMark's 10-second
            # reporting rule; every other error is a real failure.
            if "at least 10 secs" in line:
                continue
            raise SystemExit(f"CoreMark reported an error: {line}")

    if "2K performance run parameters for coremark." not in text:
        raise SystemExit("CoreMark did not recognise its own run parameters")

    seedcrc = re.search(r"^seedcrc\s+: 0x([0-9a-f]{4})$", text, re.M)
    if not seedcrc or int(seedcrc.group(1), 16) != EXPECTED_SEEDCRC:
        raise SystemExit(f"seedcrc mismatch: {seedcrc and seedcrc.group(1)}")

    for name, expected in EXPECTED_CRC.items():
        match = re.search(rf"^\[0\]crc{name}\s+: 0x([0-9a-f]{{4}})$", text, re.M)
        if not match:
            raise SystemExit(f"transcript has no {name} CRC")
        if int(match.group(1), 16) != expected:
            raise SystemExit(
                f"{name} CRC mismatch: got 0x{match.group(1)} "
                f"expected 0x{expected:04x}")

    if not re.search(r"^\[0\]crcfinal\s+: 0x[0-9a-f]{4}$", text, re.M):
        raise SystemExit("transcript has no final CRC")
    if "FINISH" not in text:
        raise SystemExit("CoreMark did not reach its final line")

    print(f"coremark transcript: PASS ({len(text)} bytes)")


if __name__ == "__main__":
    main()
