#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True


def load_script(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / filename)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {filename}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


stage5_contract = load_script("stage5_contract", "stage5_contract.py")
vivado_result = load_script("vivado_result", "check_vivado_result.py")


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


if __name__ == "__main__":
    unittest.main()
