#!/usr/bin/env python3
"""Validate and stage one named C_TEST COE for the canonical Vivado build."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


PROGRAMS = {"c-test-0", "c-test-1", "c-test-2"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_output(root: Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(root), *args], text=True
    ).strip()


def prepare(root: Path, stage_dir: Path, program: str, require_clean: bool) -> dict:
    if program not in PROGRAMS:
        raise ValueError(f"unsupported candidate {program!r}")

    program_dir = root / ".cache/programs/c_test" / program
    manifest_path = program_dir / f"{program}.manifest"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != 1 or manifest.get("program") != program:
        raise ValueError("program manifest identity does not match the candidate")

    source_commit = git_output(root, "rev-parse", "HEAD")
    dirty_output = git_output(root, "status", "--porcelain", "--untracked-files=normal")
    source_dirty = bool(dirty_output)
    manifest_source = manifest.get("source", {})
    if manifest_source.get("commit") != source_commit:
        raise ValueError("program manifest was not built from the current source commit")
    if bool(manifest_source.get("dirty")):
        raise ValueError("program manifest has dirty program/build inputs")
    if require_clean and source_dirty:
        raise ValueError("candidate bitstreams require a clean source commit")

    coe_record = manifest.get("artifacts", {}).get("coe", {})
    coe_path = root / str(coe_record.get("path", ""))
    if coe_path.resolve() != (program_dir / f"{program}.coe").resolve():
        raise ValueError("manifest COE path is not the named candidate output")
    coe_hash = sha256(coe_path)
    if coe_hash != coe_record.get("sha256"):
        raise ValueError("candidate COE hash does not match its manifest")
    if int(manifest["memory_contract"]["behavioral_memory_minimum_bytes"]) < 153_600:
        raise ValueError("candidate manifest does not require the full physical memory")

    staged_coe = stage_dir / "src/coe" / f"{program}.coe"
    staged_manifest = stage_dir / "candidate-input" / f"{program}.manifest.json"
    staged_coe.parent.mkdir(parents=True, exist_ok=True)
    staged_manifest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(coe_path, staged_coe)
    shutil.copyfile(manifest_path, staged_manifest)

    selection = {
        "schema": 1,
        "program": program,
        "source": {"commit": source_commit, "dirty": source_dirty},
        "manifest": {
            "path": str(staged_manifest.relative_to(stage_dir)),
            "sha256": sha256(staged_manifest),
        },
        "coe": {
            "path": str(staged_coe.relative_to(stage_dir)),
            "sha256": coe_hash,
            "size": staged_coe.stat().st_size,
        },
        "memory_minimum_bytes": 153_600,
    }
    selection_path = stage_dir / ".candidate-selection.json"
    selection_path.write_text(
        json.dumps(selection, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return selection


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--stage-dir", type=Path, required=True)
    parser.add_argument("--program", required=True)
    parser.add_argument("--require-clean", action="store_true")
    args = parser.parse_args()
    try:
        selection = prepare(
            args.root.resolve(),
            args.stage_dir.resolve(),
            args.program,
            args.require_clean,
        )
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        print(f"error: cannot prepare Vivado candidate: {exc}", file=sys.stderr)
        return 2
    print(f"candidate-program: {selection['program']}")
    print(f"candidate-coe: {selection['coe']['path']}")
    print(f"candidate-coe-sha256: {selection['coe']['sha256']}")
    print(f"candidate-source: {selection['source']['commit']}")
    print(f"candidate-source-dirty: {str(selection['source']['dirty']).lower()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
