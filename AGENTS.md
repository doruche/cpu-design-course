# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository. `CLAUDE.md` is a symlink to this file; edit
`AGENTS.md`.

## Scope

This is a private, single-developer course repository for the complete EGO1 +
miniRV assignment: single-cycle CPU, pipeline CPU, caches, AXI, I/O, and the
final pipeline SoC. Do not narrow work to the solo minimum grading path unless
the user explicitly changes the goal.

## Read First

Before changing RTL or workflow code, read:

1. `README.md`
2. `docs/workflow.md`
3. The active task book under `docs/devlog/`
4. The relevant section under `materials/instruction-site/docs/`
5. The relevant source and tests under `cdp-tests/`

The guide and Trace framework are pinned submodules. Treat their live source as
the course contract; do not copy their prose into local documentation.

## Working Style

These rules bias toward caution over speed. Use judgment on trivial tasks.

### Think before coding

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them; do not pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop, name what is confusing, and ask.

### Simplicity first

- Minimum code that solves the problem. Nothing speculative.
- No features beyond what was asked; no abstractions for single-use code; no
  unrequested "flexibility"; no error handling for impossible scenarios.
- If 200 lines could be 50, rewrite it. Ask whether a senior engineer would
  call it overcomplicated.

### Surgical changes

- Touch only what the request requires. Every changed line should trace
  directly back to it.
- Do not "improve" adjacent code, comments, or formatting; do not refactor what
  is not broken; match existing style.
- Remove imports, wires, parameters, or modules that *your* change orphaned.
  Mention pre-existing dead code instead of deleting it.
- Preserve unrelated user changes. Do not rewrite upstream template whitespace
  as part of feature work.

### Goal-driven execution

Convert each task into a verifiable goal before writing RTL or scripts, and
state a brief plan of `step -> verification` pairs for multi-step work. In this
repository the verification is almost always a concrete command:

- "Add an instruction" -> design CSV rows complete, then
  `just lint <config>` and `just trace <config> <case>` pass.
- "Fix the bug" -> reproduce it in a Trace case or a `tests/` testbench first,
  then make it pass.
- "Refactor X" -> the same gate passes before and after.

Loop on the command until it is green rather than asking for confirmation
between iterations.

## Build And Verification CLI

The root `Justfile` is the only public entry point; it delegates to
`scripts/build.sh`. There is no root `Makefile`, and the `closure` gate fails if
one reappears or if `make` commands return to `README.md` / `docs/workflow.md`.
`cdp-tests/Makefile` is used only as a serialized Trace backend.

```bash
git submodule update --init --recursive
just doctor                       # tool, version, and pinned-input check
just --list                       # all entry points
just status                       # repo state + stable configurations
just show-config <config>         # full resolved contract for one config
```

Verification entry points (`<config>` is always explicit, never defaulted):

```bash
just lint <config>                # verilator --lint-only --Wall, top miniRV_SoC
just trace <config> <case>        # one official Trace case, e.g. addi
just trace-all <config>           # all 45 Trace cases, serialized
just unit <suite>                 # cache | axi-master | pipeline-control
                                  # peripherals | c-test-software | stage5-contract
just integration <suite>          # fabric-mmio | dcache-mmio
just system <suite>               # soc-smoke | c-test-0 | c-test-1 | c-test-2
                                  # coremark
just program <c-test-0|1|2|coremark> # build + audit a board program image
just gate <gate>                  # aggregate gates, see below
just clean                        # remove generated repo and Trace outputs
```

Gates: `single-stage2`, `single-stage3`, `single-stage4-auto`,
`products-basic`, `closure`. `closure` is the full sweep — `just --fmt --check`,
doctor, all unit/integration suites, lint + full Trace across all ten
configurations, SoC smoke, pipeline CoreMark system simulation, `.xpr` XML
validation, and `git diff --check`.

Vivado (Windows backend, run from WSL):

```bash
just vivado <single_cycle|pipeline> <stage|synth|bitstream>
just vivado-candidate <c-test-0|1|2> [stage|bitstream]   # single-cycle bitstreams
just export-submission            # needs STUDENT_ID, STUDENT_NAME, REPORT_PDF,
                                  # PROGRAM_ASM, PROGRAM_COE
```

Machine-local Vivado settings live in the ignored `local.env` (copy from
`local.env.example`): only `VIVADO_BIN`, `VIVADO_STAGE_ROOT`, `VIVADO_JOBS`.

## Architecture

### Two products, one RTL truth each

Source is organized by final product, not course chronology.
`projects/single_cycle/` began as the Lab 1 CPU and is now the validated
single-cycle SoC; `projects/pipeline/` was forked from it and now contains the
five-stage core integrated with the SoC fabric. The pipeline RTL automation is
closed, while its physical/Vivado and board-product gates remain open. Each
product owns exactly one HDL truth source at `projects/<product>/src/rtl/`, plus
its own `miniRV.xpr`, XDC, XCI, COE, and Tcl. Everything else — Trace builds,
Windows Vivado staging, and the submission export — is generated from those.

### Configuration matrix drives every build

`config/build-configs.tsv` is the single table of stable configurations. Each
row fixes `product`, `topology`, `memory_model`, `cache`, `backend`, the
Verilog `defines`, and an artifact directory. `scripts/build.sh:load_config`
validates each tuple before selecting sources and backend behavior.

| config | product | topology | cache |
| --- | --- | --- | --- |
| `single-basic` | single_cycle | basic (`BASIC_TRACE`) | n/a |
| `single-axi-direct-bypass` | single_cycle | `AXI_DIRECT_TOPOLOGY` | bypass |
| `single-axi-direct-cache` | single_cycle | `AXI_DIRECT_TOPOLOGY` | enabled |
| `single-soc-bypass` | single_cycle | `SOC_TOPOLOGY` + MMIO | bypass |
| `single-soc-cache` | single_cycle | `SOC_TOPOLOGY` + MMIO | enabled |
| `pipeline-basic` | pipeline | basic | n/a |
| `pipeline-axi-direct-bypass` | pipeline | `AXI_DIRECT_TOPOLOGY` | bypass |
| `pipeline-axi-direct-cache` | pipeline | `AXI_DIRECT_TOPOLOGY` | enabled |
| `pipeline-soc-bypass` | pipeline | `SOC_TOPOLOGY` + MMIO | bypass |
| `pipeline-soc-cache` | pipeline | `SOC_TOPOLOGY` + MMIO | enabled |

Topology and cache selection happen through compiler defines, not by editing
`defines.vh` or forking files. `miniRV_SoC.v` is one file with `ifdef` arms for
each topology; `ICache.v`/`DCache.v` compile in both bypass and enabled form.
When adding a variant, add a row to the TSV — do not add an ad-hoc script path.

### Trace framework contract

`cdp-tests/` is a pinned submodule holding the golden 45-case Trace suite.
`scripts/build.sh` compiles canonical product RTL directly into the Verilator
Trace harness (shared `cdp-tests/obj_dir`, serialized under a `flock` on the
repo root, with `.cache/trace/current-config` forcing a clean rebuild when the
configuration changes). `cdp-tests/mySoC/` stays an untouched upstream
placeholder. On failure, compare the generated VCD against
`cdp-tests/asm/<case>.dump`.

### Design artifacts are gates, not documentation

`design/single_cycle/{datapath,control_signals}.csv` and
`design/pipeline/{stage_registers,hazards,flow_control}.csv` must be completed
*before* the corresponding RTL. `design/README.md` defines mandatory notation:
empty means "not designed yet", `-` means the field places no semantic
constraint, control symbols must match `defines.vh` macro names without the
backtick, and side-effect controls (`npc_op`, `rf_we`, `ram_rop`, `ram_wop`,
`is_mul`, `is_div`) may never be `-`. Official `demo` rows are frozen.

## RTL Contract

- Course submission RTL is synthesizable Verilog in `.v`/`.vh` files.
- SystemVerilog is allowed only for repository-owned testbenches under `tests/`.
- Preserve the required hierarchy and names: `miniRV_SoC.U_cpu.U_core`.
- Do not change code guarded by `RUN_TRACE` or signals annotated with
  `/* verilator public */` without first verifying the Trace driver contract.
- Preserve reset PC `0x00000000`; Trace reset is active high while the EGO1
  board reset is active low at the FPGA boundary.
- Never author code in `cdp-tests/mySoC/`.
- Never edit a Windows Vivado staging directory. Fix canonical project files in
  WSL and regenerate staging.
- Do not modify either submodule unless the user explicitly requests an upstream
  update or framework investigation.
- Follow `materials/instruction-site/docs/home/codingstyle.md`.

## Verification Gates

| Change level | Required validation |
| --- | --- |
| Existing RTL logic | `just lint <config>` + targeted `just trace <config> <case>` |
| Instruction group | Relevant `just unit`/`just integration` + `just trace-all <config>` |
| Clock/reset/IP/top-level | Trace plus `just vivado <product> synth` |
| Product milestone | Full Trace, implementation, timing, utilization, power |
| Release/submission | Exported-tree Trace, bitstream, user-observed board test |

- Implement Lab 1 group A before group B. Validate multiplier and divider as
  standalone modules before CPU integration.
- Bring AXI up with caches disabled, then enable and verify both caches.
- Do not claim Vivado or board validation when those steps were not run. The
  agent owns automated checks; the user owns physical programming and board
  observation.

## Git And Artifacts

- Keep `main` integrated; use short task branches rather than long-lived A/B
  branches. Preserve major milestones with tags (`upstream-lab1-template`,
  `lab1-complete`, `single-cycle-soc-stage3`, `single-cycle-soc-stage5`).
- Update submodule commits explicitly after reviewing their changes.
- Do not commit downloaded course archives, waveform dumps, Vivado run
  directories, bitstreams, or caches.
- Curated timing, utilization, and power reports may be committed under
  `artifacts/` with the source commit and tool version recorded.
