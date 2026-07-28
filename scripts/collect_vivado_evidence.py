#!/usr/bin/env python3
"""Collect and enforce Stage 5 evidence from one canonical Vivado run."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

from check_vivado_result import evaluate


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_facts(path: Path) -> dict[str, str]:
    facts: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        key, separator, value = line.partition("\t")
        if not separator or not key or key in facts:
            raise ValueError(f"malformed or duplicate build fact: {line!r}")
        facts[key] = value
    return facts


def required_max_count(text: str, name: str) -> int:
    matches = re.findall(rf"checking {re.escape(name)} \((\d+)\)", text)
    if not matches:
        raise ValueError(f"timing report has no {name} check")
    return max(int(value) for value in matches)


def required_regex_count(text: str, pattern: str, description: str) -> int:
    match = re.search(pattern, text)
    if not match:
        raise ValueError(f"timing report has no {description} section")
    return int(match.group(1))


def parse_timing(path: Path) -> dict[str, float | int]:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    summary: list[float] | None = None
    for index, line in enumerate(lines):
        if "WNS(ns)" not in line or "TNS(ns)" not in line or "WHS(ns)" not in line:
            continue
        for candidate in lines[index + 1 : index + 5]:
            tokens = candidate.split()
            if len(tokens) < 6:
                continue
            try:
                summary = [float(tokens[0]), float(tokens[1]), float(tokens[4]), float(tokens[5])]
            except ValueError:
                continue
            break
        if summary is not None:
            break
    if summary is None:
        raise ValueError("timing summary table was not found")

    no_clock = required_max_count(text, "no_clock")
    constant_clock = required_max_count(text, "constant_clock")
    unconstrained_internal = required_max_count(
        text, "unconstrained_internal_endpoints"
    )
    no_input = required_regex_count(
        text,
        r"There are (\d+) input ports with no input delay specified",
        "input-delay",
    )
    false_input = required_regex_count(
        text,
        r"There are (\d+) input ports with no input delay but user has a false path",
        "false-path input",
    )
    no_output = required_regex_count(
        text,
        r"There are (\d+) ports with no output delay specified",
        "output-delay",
    )
    false_output = required_regex_count(
        text,
        r"There are (\d+) ports with no output delay but (?:user has |with )a false path",
        "false-path output",
    )
    unconstrained = (
        no_clock
        + constant_clock
        + unconstrained_internal
        + max(0, no_input - false_input)
        + max(0, no_output - false_output)
    )
    return {
        "setup_wns_ns": summary[0],
        "setup_tns_ns": summary[1],
        "hold_whs_ns": summary[2],
        "hold_ths_ns": summary[3],
        "unconstrained_paths": unconstrained,
        "no_input_delay_ports": no_input,
        "false_path_input_ports": false_input,
        "no_output_delay_ports": no_output,
        "false_path_output_ports": false_output,
    }


def require_report(path: Path, marker: str) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if marker not in text:
        raise ValueError(f"{path.name} is empty or has an unexpected format")


def current_critical_warnings(stage_dir: Path, action: str) -> list[str]:
    marker = stage_dir / ".build-start"
    threshold = marker.stat().st_mtime - 2.0
    required_logs = [
        stage_dir / "vivado.log",
        stage_dir / "miniRV.runs/synth_1/runme.log",
    ]
    if action == "bitstream":
        required_logs.append(stage_dir / "miniRV.runs/impl_1/runme.log")
    for path in required_logs:
        if not path.is_file() or path.stat().st_mtime < threshold:
            raise ValueError(f"required current-run log is missing: {path}")
    logs = [stage_dir / "vivado.log"]
    logs.extend((stage_dir / "miniRV.runs").glob("*/runme.log"))
    messages: set[str] = set()
    for path in logs:
        if not path.is_file() or path.stat().st_mtime < threshold:
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "CRITICAL WARNING:" in line:
                messages.add(line.strip())
    return sorted(messages)


def windows_basename(value: str) -> str:
    return Path(value.replace("\\", "/")).name


def collect(stage_dir: Path, action: str) -> dict:
    artifact_dir = stage_dir / "artifacts"
    facts = read_facts(artifact_dir / "build_facts.tsv")
    if facts.get("schema") != "1" or facts.get("action") != action:
        raise ValueError("build facts do not match this Vivado action")
    if facts.get("part", "").lower() != "xc7a35tcsg324-1":
        raise ValueError(f"unexpected target part {facts.get('part')!r}")
    if facts.get("vivado_version") != "2023.2":
        raise ValueError(
            f"Stage 5 requires Vivado 2023.2, got {facts.get('vivado_version')!r}"
        )
    width = int(facts["bram_width_bits"])
    depth = int(facts["bram_depth_words"])
    if width != 32 or depth < 38_400:
        raise ValueError("Vivado did not consume the full Stage 5 BRAM depth")

    critical_lines = current_critical_warnings(stage_dir, action)
    base = {
        "schema": 1,
        "action": action,
        "tool": {"vivado": facts["vivado_version"]},
        "part": facts["part"],
        "runs": {
            "synth_complete": facts["synth_complete"] == "1",
            "impl_complete": facts["impl_complete"] == "1",
        },
        "memory": {
            "width_bits": width,
            "depth_words": depth,
            "capacity_bytes": width * depth // 8,
        },
        "coe": {
            "requested": facts["requested_coe"],
            "actual": facts["actual_coe"],
        },
        "messages": {
            "critical_warning_count": len(critical_lines),
            "critical_warnings": critical_lines,
        },
    }
    if action == "synth":
        if not base["runs"]["synth_complete"]:
            raise ValueError("synthesis did not complete")
        if critical_lines:
            raise ValueError("synthesis emitted a critical warning")
        return base

    selection = json.loads(
        (stage_dir / ".candidate-selection.json").read_text(encoding="utf-8")
    )
    if selection.get("schema") != 1 or selection["source"]["dirty"] is not False:
        raise ValueError("bitstream candidate source is not a clean commit")
    program = selection["program"]
    if windows_basename(facts["requested_coe"]) != f"{program}.coe":
        raise ValueError("requested COE does not match candidate identity")
    if facts["requested_coe"].lower() != facts["actual_coe"].lower():
        raise ValueError("actual bram_axi COE differs from the requested COE")
    staged_coe = stage_dir / selection["coe"]["path"]
    if sha256(staged_coe) != selection["coe"]["sha256"]:
        raise ValueError("staged COE hash changed after candidate selection")
    staged_manifest = stage_dir / selection["manifest"]["path"]
    if sha256(staged_manifest) != selection["manifest"]["sha256"]:
        raise ValueError("staged manifest hash changed after candidate selection")

    bitstreams = list(artifact_dir.glob("*.bit"))
    if len(bitstreams) != 1:
        raise ValueError(f"expected one bitstream, found {len(bitstreams)}")
    timing = parse_timing(artifact_dir / "timing_summary.rpt")
    require_report(artifact_dir / "drc.rpt", "Report DRC")
    require_report(artifact_dir / "methodology.rpt", "Report Methodology")
    require_report(artifact_dir / "cdc.rpt", "CDC Report")
    drc_errors = int(facts["drc_error_count"])
    drc_critical = int(facts["drc_critical_warning_count"])
    methodology_critical = int(facts["methodology_critical_warning_count"])

    snapshot_dir = artifact_dir / "candidate-input"
    snapshot_dir.mkdir(exist_ok=True)
    selection_snapshot = snapshot_dir / "candidate-selection.json"
    manifest_snapshot = snapshot_dir / f"{program}.manifest.json"
    coe_snapshot = snapshot_dir / f"{program}.coe"
    shutil.copyfile(stage_dir / ".candidate-selection.json", selection_snapshot)
    shutil.copyfile(staged_manifest, manifest_snapshot)
    shutil.copyfile(staged_coe, coe_snapshot)
    base["timing"] = timing
    base["drc"] = {
        "error_count": drc_errors,
        "critical_warning_count": drc_critical,
    }
    base["messages"]["methodology_critical_warning_count"] = methodology_critical
    base["messages"]["critical_warning_count"] += methodology_critical
    base["candidate"] = {
        "program": program,
        "source_commit": selection["source"]["commit"],
        "selection": {
            "path": str(selection_snapshot.relative_to(artifact_dir)),
            "sha256": sha256(selection_snapshot),
        },
        "manifest": {
            "path": str(manifest_snapshot.relative_to(artifact_dir)),
            "sha256": sha256(manifest_snapshot),
        },
        "coe": {
            "path": str(coe_snapshot.relative_to(artifact_dir)),
            "sha256": sha256(coe_snapshot),
        },
        "bitstream": {
            "path": bitstreams[0].name,
            "sha256": sha256(bitstreams[0]),
            "size": bitstreams[0].stat().st_size,
        },
    }
    return base


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage-dir", type=Path, required=True)
    parser.add_argument("--action", choices=("synth", "bitstream"), required=True)
    args = parser.parse_args()
    try:
        result = collect(args.stage_dir.resolve(), args.action)
        errors = evaluate(result) if args.action == "bitstream" else []
        if errors:
            raise ValueError("; ".join(errors))
        output = args.stage_dir.resolve() / "artifacts" / "stage5_evidence.json"
        output.write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: Vivado evidence rejected: {exc}", file=sys.stderr)
        return 2
    if args.action == "bitstream":
        candidate = result["candidate"]
        print(f"candidate-bitstream-sha256: {candidate['bitstream']['sha256']}")
        print(f"candidate-evidence: {output}")
    else:
        print(f"synthesis-evidence: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
