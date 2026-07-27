#!/usr/bin/env python3
"""Apply the Stage 5 machine verdict to structured Vivado evidence."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def evaluate(result: dict) -> list[str]:
    errors: list[str] = []
    try:
        if result["schema"] != 1:
            errors.append(f"unsupported evidence schema {result['schema']!r}")
        if result["runs"]["synth_complete"] is not True:
            errors.append("synthesis run is not complete")
        if result["runs"]["impl_complete"] is not True:
            errors.append("implementation run is not complete")

        timing = result["timing"]
        setup_wns = float(timing["setup_wns_ns"])
        setup_tns = float(timing["setup_tns_ns"])
        hold_whs = float(timing["hold_whs_ns"])
        hold_ths = float(timing["hold_ths_ns"])
        unconstrained = int(timing["unconstrained_paths"])
        if setup_wns < 0:
            errors.append(f"setup WNS is negative: {setup_wns:g} ns")
        if setup_tns < 0:
            errors.append(f"setup TNS is negative: {setup_tns:g} ns")
        if hold_whs < 0:
            errors.append(f"hold WHS is negative: {hold_whs:g} ns")
        if hold_ths < 0:
            errors.append(f"hold THS is negative: {hold_ths:g} ns")
        if unconstrained != 0:
            errors.append(f"unconstrained path count is {unconstrained}, expected zero")

        drc = result["drc"]
        drc_errors = int(drc["error_count"])
        drc_critical = int(drc["critical_warning_count"])
        if drc_errors != 0:
            errors.append(f"implementation DRC error count is {drc_errors}")
        if drc_critical != 0:
            errors.append(
                f"implementation DRC critical-warning count is {drc_critical}"
            )

        critical_messages = int(result["messages"]["critical_warning_count"])
        if critical_messages != 0:
            errors.append(
                f"Vivado critical-warning message count is {critical_messages}"
            )
    except (KeyError, TypeError, ValueError) as exc:
        errors.append(f"malformed Vivado evidence: {exc}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()
    try:
        result = json.loads(args.evidence.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: cannot read Vivado evidence: {exc}", file=sys.stderr)
        return 1

    errors = evaluate(result)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("Vivado implementation contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
