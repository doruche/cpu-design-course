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
import xml.etree.ElementTree as ET
from pathlib import Path


MIN_MEMORY_BYTES = 153_600
CPU_CLOCK_HZ = 50_000_000
UART_BAUD = 115_200
EXPECTED_PART = "xc7a35tcsg324-1"

PIPELINE_DESIGN_SOURCES = {
    f"$PPRDIR/src/rtl/{name}"
    for name in (
        "ALU.v",
        "Controller.v",
        "DCache.v",
        "Data_RAM.v",
        "ICache.v",
        "Inst_ROM.v",
        "MEXT.v",
        "MREQ.v",
        "NPC.v",
        "PC.v",
        "RF.v",
        "SEXT.v",
        "axi_master.v",
        "cpu_core.v",
        "cpu_top.v",
        "divider.v",
        "miniRV_SoC.v",
        "multiplier.v",
        "seven_segment.v",
        "soc_interconnect.v",
        "soc_peripherals.v",
        "uart_peripheral.v",
    )
}
PIPELINE_DESIGN_SOURCES.add("$PPRDIR/src/coe/stage5-placeholder.coe")
PIPELINE_BLOCK_SOURCES = {
    "bram_axi": "$PPRDIR/src/rtl/ip/bram_axi/bram_axi.xci",
    "clk_wiz_0": "$PPRDIR/src/rtl/ip/clk_wiz_0/clk_wiz_0.xci",
}
PIPELINE_CONSTRAINTS = {
    "$PPRDIR/src/xdc/clock.xdc",
    "$PPRDIR/src/xdc/miniRV_SoC.xdc",
    "$PPRDIR/src/xdc/stage5.xdc",
}


def component_record(document: dict, name: str) -> dict:
    parameter_sets = document["ip_inst"]["parameters"]
    values = None
    for section in ("component_parameters", "model_parameters"):
        candidate = parameter_sets.get(section, {}).get(name)
        if candidate is not None:
            values = candidate
            break
    if not isinstance(values, list) or not values:
        raise ValueError(f"XCI parameter {name} has no value")
    if not isinstance(values[0], dict):
        raise ValueError(f"XCI parameter {name} record is invalid")
    return values[0]


def component_value(document: dict, name: str) -> str:
    return str(component_record(document, name)["value"])


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


def format_items(items: set[str]) -> str:
    return ", ".join(sorted(items))


def find_fileset(project: ET.Element, name: str) -> ET.Element:
    fileset = project.find(f"./FileSets/FileSet[@Name='{name}']")
    if fileset is None:
        raise ValueError(f"XPR fileset {name} was not found")
    return fileset


def fileset_paths(fileset: ET.Element) -> set[str]:
    return {
        path
        for file_node in fileset.findall("./File")
        if (path := file_node.get("Path")) is not None
    }


def option_value(parent: ET.Element, name: str) -> str:
    option = parent.find(f"./Option[@Name='{name}']")
    if option is None or option.get("Val") is None:
        raise ValueError(f"XPR option {name} was not found")
    return str(option.get("Val"))


def required_child(parent: ET.Element, path: str, label: str) -> ET.Element:
    child = parent.find(path)
    if child is None:
        raise ValueError(f"XPR {label} was not found")
    return child


def run_flow(project: ET.Element, run_id: str) -> tuple[ET.Element, str]:
    run = project.find(f"./Runs/Run[@Id='{run_id}']")
    if run is None:
        raise ValueError(f"XPR run {run_id} was not found")
    handle = run.find("./Strategy/StratHandle")
    if handle is None or handle.get("Flow") is None:
        raise ValueError(f"XPR run {run_id} has no strategy flow")
    return run, str(handle.get("Flow"))


def audit_pipeline_xpr(root: Path) -> list[str]:
    errors: list[str] = []
    xpr_path = root / "projects/pipeline/miniRV.xpr"
    try:
        project = ET.parse(xpr_path).getroot()
        configuration = required_child(project, "./Configuration", "Configuration")
        part = option_value(configuration, "Part")
        design_set = find_fileset(project, "sources_1")
        design_sources = fileset_paths(design_set)
        constraints = fileset_paths(find_fileset(project, "constrs_1"))
        block_sources = {
            str(fileset.get("Name")): next(iter(fileset_paths(fileset)), "")
            for fileset in project.findall("./FileSets/FileSet[@Type='BlockSrcs']")
        }
        design_config = required_child(design_set, "./Config", "sources_1 Config")
        top = option_value(design_config, "TopModule")
        synth_run, synth_flow = run_flow(project, "synth_1")
        impl_run, impl_flow = run_flow(project, "impl_1")
        print(
            "pipeline XPR: "
            f"part={part} top={top} DesignSrcs={len(design_sources)} "
            f"BlockSrcs={','.join(sorted(block_sources))} "
            f"constraints={len(constraints)} "
            f"flows={synth_flow}/{impl_flow}"
        )

        missing_sources = PIPELINE_DESIGN_SOURCES - design_sources
        extra_sources = design_sources - PIPELINE_DESIGN_SOURCES
        if missing_sources:
            errors.append(
                "pipeline XPR DesignSrcs missing: " + format_items(missing_sources)
            )
        if extra_sources:
            errors.append(
                "pipeline XPR DesignSrcs stale/unexpected: "
                + format_items(extra_sources)
            )
        if block_sources != PIPELINE_BLOCK_SOURCES:
            missing_blocks = set(PIPELINE_BLOCK_SOURCES) - set(block_sources)
            stale_blocks = set(block_sources) - set(PIPELINE_BLOCK_SOURCES)
            if missing_blocks:
                errors.append(
                    "pipeline XPR BlockSrcs missing: " + format_items(missing_blocks)
                )
            if stale_blocks:
                errors.append(
                    "pipeline XPR BlockSrcs stale/unexpected: "
                    + format_items(stale_blocks)
                )
            wrong_paths = {
                name
                for name in set(block_sources) & set(PIPELINE_BLOCK_SOURCES)
                if block_sources[name] != PIPELINE_BLOCK_SOURCES[name]
            }
            if wrong_paths:
                errors.append(
                    "pipeline XPR BlockSrcs path mismatch: "
                    + format_items(wrong_paths)
                )
        missing_constraints = PIPELINE_CONSTRAINTS - constraints
        extra_constraints = constraints - PIPELINE_CONSTRAINTS
        if missing_constraints:
            errors.append(
                "pipeline XPR constraints missing: "
                + format_items(missing_constraints)
            )
        if extra_constraints:
            errors.append(
                "pipeline XPR constraints stale/unexpected: "
                + format_items(extra_constraints)
            )
        if part != EXPECTED_PART:
            errors.append(f"pipeline XPR part is {part}, expected {EXPECTED_PART}")
        if top != "miniRV_SoC":
            errors.append(f"pipeline XPR top is {top}, expected miniRV_SoC")
        if synth_run.get("SrcSet") != "sources_1" or synth_run.get("ConstrsSet") != "constrs_1":
            errors.append("pipeline synth_1 does not own sources_1/constrs_1")
        if impl_run.get("SynthRun") != "synth_1" or impl_run.get("ConstrsSet") != "constrs_1":
            errors.append("pipeline impl_1 does not own synth_1/constrs_1")
        if synth_flow != "Vivado Synthesis 2023":
            errors.append(
                f"pipeline synth_1 flow is {synth_flow}, expected Vivado Synthesis 2023"
            )
        if impl_flow != "Vivado Implementation 2023":
            errors.append(
                "pipeline impl_1 flow is "
                f"{impl_flow}, expected Vivado Implementation 2023"
            )
    except (OSError, TypeError, ValueError, ET.ParseError) as exc:
        errors.append(f"cannot audit pipeline XPR: {exc}")
    return errors


def check_static_contract(root: Path, product: str = "single_cycle") -> list[str]:
    errors: list[str] = []
    product_root = root / "projects" / product
    bram_path = product_root / "src/rtl/ip/bram_axi/bram_axi.xci"
    clock_path = product_root / "src/rtl/ip/clk_wiz_0/clk_wiz_0.xci"
    peripheral_path = product_root / "src/rtl/soc_peripherals.v"
    uart_path = product_root / "src/rtl/uart_peripheral.v"
    runtime_path = root / "programs/c_test/runtime/c_test_io.h"

    if product == "pipeline":
        errors.extend(audit_pipeline_xpr(root))

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
        coe_value_source = str(component_record(bram, "Coe_File").get("value_src", ""))
        load_init_file = component_value(bram, "Load_Init_File").lower()
        print(
            f"{product} BRAM: width={width} bits depth={depth} words "
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
        if product == "pipeline" and Path(coe_file.replace("\\", "/")).name != "stage5-placeholder.coe":
            errors.append("pipeline BRAM XCI does not name stage5-placeholder.coe")
        if product == "pipeline" and (
            coe_value_source != "user" or load_init_file != "true"
        ):
            errors.append("pipeline BRAM XCI does not expose a user COE override")
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
            f"{product} Clock Wizard: input={input_mhz:g} MHz output={output_mhz:g} MHz "
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
            f"{product} product parameters: "
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
    parser.add_argument(
        "--product",
        choices=("single_cycle", "pipeline"),
        default="single_cycle",
        help="canonical product to audit",
    )
    args = parser.parse_args()
    errors = check_static_contract(args.root.resolve(), args.product)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"stage5 {args.product} static physical contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
