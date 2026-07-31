# Changelog

All notable changes to this repository are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This is a course
repository rather than a released product, so the section headings are the
milestone tags described in `AGENTS.md` instead of semantic versions.

Board results are only recorded when the user observed them on real hardware.
Simulation-only numbers are labelled as such.

## [Unreleased]

### Changed

- Vendored the Trace framework into `tests/cdp/` and turned the official guide
  into an ignored local snapshot at `docs/instruction-site/`, flattened from the
  guide's `docs/` tree. Neither path is a Git submodule any more, and
  `.gitmodules` is gone.
- Moved the documentation tree: `materials/MANIFEST.md` to `docs/MANIFEST.md`,
  `design/` to `docs/acceptance/design/`, `artifacts/` to `docs/acceptance/`
  (formal Vivado reports now under `docs/acceptance/benchmark/`).
- Updated every affected path in `scripts/build.sh`, `scripts/doctor.sh`,
  `scripts/export-submission.sh`, the two `config/verilator-*.vlt` waiver
  baselines, `README.md`, `AGENTS.md`, `.gitignore`, and the Markdown and TSV
  files under `docs/`.
- `just doctor` no longer checks submodule pins; it checks
  `tests/cdp/Makefile` and `docs/instruction-site/index.md` as repository
  inputs. `just status` no longer prints submodule status.

### Removed

- The ignored `materials/lab1/` and `materials/lab2/` download areas, together
  with the optional "Restricted local materials" section of `just doctor`.
  Course-download provenance stays in `docs/MANIFEST.md`; the files themselves
  now live outside the repository.
- `materials/lab2-requirements-snapshot.md`, which is readable from Git history
  at `c436fc0`.

### Added

- `LICENSE`, `SECURITY.md`, and this changelog.

## [pipeline-soc-stage5] - 2026-07-30

### Added

- Five-stage IF/ID/EX/MEM/WB pipeline core, forked from the validated
  single-cycle baseline and integrated with the verified cache, AXI, main
  memory/MMIO interconnect, and peripheral fabric.
- Pipeline CoreMark board program plus the `coremark` system suite.
- `just unit pipeline-control` and the `stage5-contract` suite.
- Live acceptance material under `docs/acceptance/`: acceptance matrix, demo
  runbook, evidence contract and handoff, oral-review reference answers, and
  the curated timing, utilization, and power reports.

### Changed

- Instruction fetch issues one request per cycle, and the Booth multiplier
  fuses its add and shift into a single cycle.

### Verified

- Lint and all 45 Trace cases across all five pipeline configurations,
  pipeline C_TEST 0 to 2, and the CoreMark RTL system simulation.
- Canonical Vivado 2023.2 clean implementation at 50 MHz.
- Four traceable C_TEST/CoreMark bitstreams passed the machine audit and the
  user's EGO1 board checks. User-observed CoreMark: 49.7197 CoreMark,
  0.9943 CoreMark/MHz.
- Course report body, PDF, and submission packaging remain separate work and
  are not claimed here.

## [single-cycle-soc-stage5] - 2026-07-28

### Added

- Own single-cycle SoC physical Vivado project, three traceable candidate
  bitstreams, and the C_TEST 0 to 2 programs with auditable board images.
- Devcontainer carrying the pinned Linux toolchain.

### Verified

- 50 MHz clean Vivado 2023.2 implementation; the user's EGO1 board checks
  passed on all three candidates.
- Formal artifacts, datapath diagrams, the final report, and submission
  packaging were explicitly deferred rather than reported as complete.

## [single-cycle-soc-stage3] - 2026-07-26

### Added

- Cache, AXI main-memory and MMIO interconnect, and five peripheral classes
  (switches, LEDs, seven-segment display, UART, timer) on the default
  single-cycle product path.
- `cache`, `axi-master`, and `peripherals` unit suites plus the `fabric-mmio`
  and `dcache-mmio` integration suites.
- The root `Justfile` as the only public build and verification CLI, driven by
  the ten stable configurations in `config/build-configs.tsv`; the previous
  `make` entry points were removed.

### Verified

- Full link, error-transaction, sub-word access, and peripheral-boundary
  coverage for Stage 3; cache-enabled CPU-driven SoC smoke over main memory
  and all five MMIO classes.

## [lab1-complete] - 2026-07-20

### Added

- Complete single-cycle miniRV CPU: instruction group A, then group B with the
  standalone-validated multiplier and divider.
- Single-cycle datapath and control-signal CSV design gates, and the
  presentation datapath diagram.

### Verified

- Lint and all 45 Trace cases, including the repaired `start` case, with
  Verilator 5.051.
- Vivado 2023.2 synthesis and implementation ran on the Windows backend. Lab 1
  does not require a board test, and none was claimed for this milestone.

## [upstream-lab1-template] - 2026-07-13

### Added

- Imported the official `miniRV_basic_ego1` Vivado project as the untouched
  Lab 1 baseline, the pinned Trace framework, and the reproducible course
  workflow documentation.
- Recorded the template verification baseline in `docs/baseline.md`.
