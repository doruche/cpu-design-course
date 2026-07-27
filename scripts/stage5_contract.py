#!/usr/bin/env python3
"""Check stable Stage 5 physical-product contracts.

This checker deliberately reads structured XCI data and named RTL/software
parameters.  It does not try to recognize implementation style in source text;
clock/reset behavior is covered by a separate simulation.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


MIN_MEMORY_BYTES = 153_600
CPU_CLOCK_HZ = 50_000_000
UART_BAUD = 115_200


def component_value(document: dict, name: str) -> str:
    parameter_sets = document["ip_inst"]["parameters"]
    values = None
    for section in ("component_parameters", "model_parameters"):
        candidate = parameter_sets.get(section, {}).get(name)
        if candidate is not None:
            values = candidate
            break
    if not isinstance(values, list) or not values:
        raise ValueError(f"XCI parameter {name} has no value")
    return str(values[0]["value"])


def named_integer(source: str, name: str) -> int:
    pattern = rf"\b{name}\s*=\s*([0-9][0-9_]*)"
    match = re.search(pattern, source)
    if match is None:
        raise ValueError(f"named integer {name} was not found")
    return int(match.group(1).replace("_", ""))


def macro_integer(source: str, name: str) -> int:
    pattern = rf"^\s*#define\s+{name}\s+([0-9][0-9_]*)[uUlL]*\s*$"
    match = re.search(pattern, source, re.MULTILINE)
    if match is None:
        raise ValueError(f"integer macro {name} was not found")
    return int(match.group(1).replace("_", ""))


def check_static_contract(root: Path) -> list[str]:
    errors: list[str] = []
    bram_path = root / "projects/single_cycle/src/rtl/ip/bram_axi/bram_axi.xci"
    clock_path = root / "projects/single_cycle/src/rtl/ip/clk_wiz_0/clk_wiz_0.xci"
    peripheral_path = root / "projects/single_cycle/src/rtl/soc_peripherals.v"
    uart_path = root / "projects/single_cycle/src/rtl/uart_peripheral.v"
    runtime_path = root / "programs/c_test/runtime/c_test_io.h"

    try:
        bram = json.loads(bram_path.read_text(encoding="utf-8"))
        width = int(component_value(bram, "Write_Width_A"))
        depth = int(component_value(bram, "Write_Depth_A"))
        generated_depths = {
            int(component_value(bram, name))
            for name in (
                "C_WRITE_DEPTH_A",
                "C_READ_DEPTH_A",
                "C_WRITE_DEPTH_B",
                "C_READ_DEPTH_B",
            )
        }
        generated_address_widths = {
            int(component_value(bram, name))
            for name in ("C_ADDRA_WIDTH", "C_ADDRB_WIDTH")
        }
        memory_bytes = width * depth // 8
        coe_file = component_value(bram, "Coe_File")
        print(
            f"BRAM: width={width} bits depth={depth} words "
            f"capacity={memory_bytes} bytes Coe_File={coe_file}"
        )
        if width != 32:
            errors.append(f"BRAM AXI width is {width}, expected 32 bits")
        if memory_bytes < MIN_MEMORY_BYTES:
            errors.append(
                f"BRAM AXI capacity is {memory_bytes} bytes; "
                f"need at least {MIN_MEMORY_BYTES}"
            )
        if generated_depths != {depth}:
            errors.append("BRAM generated depth metadata differs from Write_Depth_A")
        if generated_address_widths != {(depth - 1).bit_length()}:
            errors.append("BRAM generated address width does not cover its depth")
        if Path(coe_file.replace("\\", "/")).name.lower() == "lw.coe":
            errors.append(
                "BRAM AXI still has the legacy implicit lw.coe initialization"
            )
        coe_path = (bram_path.parent / coe_file).resolve()
        if not coe_path.is_file():
            errors.append(f"tracked BRAM placeholder COE does not exist: {coe_path}")
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        errors.append(f"cannot audit BRAM XCI: {exc}")

    try:
        clock = json.loads(clock_path.read_text(encoding="utf-8"))
        input_mhz = float(component_value(clock, "PRIM_IN_FREQ"))
        output_mhz = float(component_value(clock, "CLKOUT1_REQUESTED_OUT_FREQ"))
        output_driver = component_value(clock, "CLKOUT1_DRIVES")
        use_locked = component_value(clock, "USE_LOCKED").lower()
        print(
            f"Clock Wizard: input={input_mhz:g} MHz output={output_mhz:g} MHz "
            f"driver={output_driver} locked={use_locked}"
        )
        if input_mhz != 100.0:
            errors.append(f"Clock Wizard input is {input_mhz:g} MHz, expected 100")
        if output_mhz != 50.0:
            errors.append(f"Clock Wizard output is {output_mhz:g} MHz, expected 50")
        if output_driver != "BUFG":
            errors.append(f"Clock Wizard output driver is {output_driver}, expected BUFG")
        if use_locked != "true":
            errors.append("Clock Wizard must expose its locked output")
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        errors.append(f"cannot audit Clock Wizard XCI: {exc}")

    try:
        peripheral_source = peripheral_path.read_text(encoding="utf-8")
        uart_source = uart_path.read_text(encoding="utf-8")
        runtime_source = runtime_path.read_text(encoding="utf-8")
        peripheral_clock = named_integer(peripheral_source, "CLOCK_FREQ")
        peripheral_baud = named_integer(peripheral_source, "UART_BAUD_RATE")
        uart_clock = named_integer(uart_source, "CLOCK_FREQ")
        uart_baud = named_integer(uart_source, "BAUD_RATE")
        c_clock = macro_integer(runtime_source, "C_TEST_CPU_CLOCK_HZ")
        print(
            "Product parameters: "
            f"peripheral/timer={peripheral_clock} Hz, "
            f"UART={uart_clock} Hz/{uart_baud} baud, "
            f"C_TEST={c_clock} Hz"
        )
        if peripheral_clock != CPU_CLOCK_HZ:
            errors.append("soc_peripherals CLOCK_FREQ is not 50 MHz")
        if uart_clock != CPU_CLOCK_HZ:
            errors.append("uart_peripheral CLOCK_FREQ is not 50 MHz")
        if c_clock != CPU_CLOCK_HZ:
            errors.append("C_TEST_CPU_CLOCK_HZ is not 50 MHz")
        if peripheral_baud != UART_BAUD or uart_baud != UART_BAUD:
            errors.append("product UART defaults are not consistently 115200 baud")
    except (OSError, ValueError) as exc:
        errors.append(f"cannot audit product clock parameters: {exc}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="repository root",
    )
    args = parser.parse_args()
    errors = check_static_contract(args.root.resolve())
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("stage5 static physical contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
