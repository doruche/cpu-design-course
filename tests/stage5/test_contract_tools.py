#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "scripts"))


def load_script(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {filename}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


stage5_contract = load_script("stage5_contract", "stage5_contract.py")
vivado_result = load_script("vivado_result", "check_vivado_result.py")
vivado_evidence = load_script("vivado_evidence", "collect_vivado_evidence.py")
vivado_candidate = load_script(
    "vivado_candidate", "prepare_vivado_candidate.py"
)


class StaticHelperTests(unittest.TestCase):
    def test_named_integer_accepts_verilog_separators(self) -> None:
        self.assertEqual(
            stage5_contract.named_integer("parameter CLOCK_FREQ = 50_000_000", "CLOCK_FREQ"),
            50_000_000,
        )

    def test_component_value_reads_xci_shape(self) -> None:
        document = {
            "ip_inst": {
                "parameters": {
                    "component_parameters": {"Write_Depth_A": [{"value": "38400"}]}
                }
            }
        }
        self.assertEqual(stage5_contract.component_value(document, "Write_Depth_A"), "38400")

    def test_pipeline_static_contract_is_closed(self) -> None:
        self.assertEqual(stage5_contract.check_static_contract(ROOT, "pipeline"), [])


class VivadoCandidateTests(unittest.TestCase):
    def write_program(self, root: Path, program: str, commit: str) -> None:
        program_dir = root / ".cache/programs/c_test" / program
        program_dir.mkdir(parents=True)
        coe_path = program_dir / f"{program}.coe"
        coe_path.write_text(
            "memory_initialization_radix=16;\nmemory_initialization_vector=\n0;\n",
            encoding="utf-8",
        )
        manifest = {
            "schema": 1,
            "program": program,
            "source": {"commit": commit, "dirty": False},
            "artifacts": {
                "coe": {
                    "path": str(coe_path.relative_to(root)),
                    "sha256": vivado_candidate.sha256(coe_path),
                }
            },
            "memory_contract": {"behavioral_memory_minimum_bytes": 153_600},
        }
        (program_dir / f"{program}.manifest").write_text(
            json.dumps(manifest), encoding="utf-8"
        )

    def test_product_candidate_matrix_stages_manifest_and_coe(self) -> None:
        supported = {
            "single_cycle": ("c-test-0", "c-test-1", "c-test-2"),
            "pipeline": ("c-test-0", "c-test-1", "c-test-2", "coremark"),
        }
        commit = "1" * 40
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for program in {item for values in supported.values() for item in values}:
                self.write_program(root, program, commit)
            with mock.patch.object(
                vivado_candidate,
                "git_output",
                side_effect=lambda _root, *args: commit
                if args == ("rev-parse", "HEAD")
                else "",
            ):
                for product, programs in supported.items():
                    for program in programs:
                        with self.subTest(product=product, program=program):
                            stage_dir = root / "stage" / product / program
                            selection = vivado_candidate.prepare(
                                root, stage_dir, product, program, False
                            )
                            self.assertEqual(selection["product"], product)
                            self.assertEqual(selection["program"], program)
                            self.assertTrue(
                                (stage_dir / selection["manifest"]["path"]).is_file()
                            )
                            self.assertTrue(
                                (stage_dir / selection["coe"]["path"]).is_file()
                            )

    def test_rejects_candidate_outside_product_contract(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "unsupported candidate"):
                vivado_candidate.prepare(
                    Path(directory),
                    Path(directory) / "stage",
                    "single_cycle",
                    "coremark",
                    False,
                )


class VivadoVerdictTests(unittest.TestCase):
    def good_result(self) -> dict:
        return {
            "schema": 1,
            "runs": {"synth_complete": True, "impl_complete": True},
            "timing": {
                "setup_wns_ns": 0.125,
                "setup_tns_ns": 0.0,
                "hold_whs_ns": 0.031,
                "hold_ths_ns": 0.0,
                "unconstrained_paths": 0,
            },
            "drc": {"error_count": 0, "critical_warning_count": 0},
            "messages": {"critical_warning_count": 0},
        }

    def test_accepts_closed_implementation(self) -> None:
        self.assertEqual(vivado_result.evaluate(self.good_result()), [])

    def test_rejects_each_blocking_condition(self) -> None:
        mutations = (
            ("setup", lambda item: item["timing"].update(setup_wns_ns=-0.001)),
            ("setup total", lambda item: item["timing"].update(setup_tns_ns=-0.001)),
            ("hold", lambda item: item["timing"].update(hold_whs_ns=-0.001)),
            ("hold total", lambda item: item["timing"].update(hold_ths_ns=-0.001)),
            ("unconstrained", lambda item: item["timing"].update(unconstrained_paths=1)),
            ("DRC error", lambda item: item["drc"].update(error_count=1)),
            (
                "DRC critical warning",
                lambda item: item["drc"].update(critical_warning_count=1),
            ),
            (
                "Vivado critical warning",
                lambda item: item["messages"].update(critical_warning_count=1),
            ),
        )
        for label, mutate in mutations:
            with self.subTest(label=label):
                item = json.loads(json.dumps(self.good_result()))
                mutate(item)
                self.assertTrue(vivado_result.evaluate(item))

    def test_rejects_missing_evidence(self) -> None:
        self.assertTrue(vivado_result.evaluate({"schema": 1}))


class VivadoReportParserTests(unittest.TestCase):
    def test_timing_parser_accounts_for_false_path_io(self) -> None:
        report = """
1. checking no_clock (0)
2. checking constant_clock (0)
3. checking unconstrained_internal_endpoints (0)
 There are 18 input ports with no input delay specified. (HIGH)
 There are 18 input ports with no input delay but user has a false path constraint.
 There are 39 ports with no output delay specified. (HIGH)
 There are 39 ports with no output delay but with a false path constraint
 WNS(ns) TNS(ns) TNS Failing Endpoints TNS Total Endpoints WHS(ns) THS(ns)
 ------- ------- --------------------- ------------------- ------- -------
 0.112 0.000 0 8464 0.038 0.000 0 8464
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "timing.rpt"
            path.write_text(report, encoding="utf-8")
            timing = vivado_evidence.parse_timing(path)
        self.assertEqual(timing["setup_wns_ns"], 0.112)
        self.assertEqual(timing["hold_whs_ns"], 0.038)
        self.assertEqual(timing["unconstrained_paths"], 0)

    def test_timing_parser_rejects_missing_check_timing_section(self) -> None:
        report = """
WNS(ns) TNS(ns) TNS Failing Endpoints TNS Total Endpoints WHS(ns) THS(ns)
------- ------- --------------------- ------------------- ------- -------
0.112 0.000 0 8464 0.038 0.000 0 8464
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "timing.rpt"
            path.write_text(report, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "no no_clock check"):
                vivado_evidence.parse_timing(path)

    def test_report_marker_is_required(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "drc.rpt"
            path.write_text("", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "unexpected format"):
                vivado_evidence.require_report(path, "Report DRC")

    def test_cdc_report_uses_vivado_title_order(self) -> None:
        report = """\
| Command      : report_cdc -details -file cdc.rpt

CDC Report

ID     Severity  Count  Description
CDC-3  Info         17  1-bit synchronized with ASYNC_REG property
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cdc.rpt"
            path.write_text(report, encoding="utf-8")
            vivado_evidence.require_report(path, "CDC Report")


if __name__ == "__main__":
    unittest.main()
