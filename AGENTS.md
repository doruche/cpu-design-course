# Repository Instructions

## Scope

This is a private, single-developer course repository for the complete EGO1 +
miniRV assignment: single-cycle CPU, pipeline CPU, caches, AXI, I/O, and the
final pipeline SoC. Do not narrow work to the solo minimum grading path unless
the user explicitly changes the goal.

## Read First

Before changing RTL or workflow code, read:

1. `README.md`
2. `docs/workflow.md`
3. The relevant section under `materials/instruction-site/docs/`
4. The relevant source and tests under `cdp-tests/`

The guide and Trace framework are pinned submodules. Treat their live source as
the course contract; do not copy their prose into local documentation.

## Source Of Truth

- Author RTL only under `projects/single_cycle/src/rtl/` or the future
  `projects/pipeline/src/rtl/`.
- Never author code in `cdp-tests/mySoC/`; Trace consumes canonical RTL
  directly.
- Never edit a Windows Vivado staging directory. Fix canonical project files in
  WSL and regenerate staging.
- Keep board configuration changes in the canonical `.xpr`, `.xci`, `.xdc`,
  `.coe`, and build Tcl files.
- Do not modify either submodule unless the user explicitly requests an
  upstream update or framework investigation.

## RTL Contract

- Course submission RTL is synthesizable Verilog in `.v`/`.vh` files.
- SystemVerilog is allowed only for repository-owned testbenches.
- Preserve the required hierarchy and names:
  `miniRV_SoC.U_cpu.U_core`.
- Do not change code guarded by `RUN_TRACE` or signals annotated with
  `/* verilator public */` without first verifying the Trace driver contract.
- Preserve reset PC `0x00000000`; Trace reset is active high while EGO1 board
  reset is active low at the FPGA boundary.
- Follow `materials/instruction-site/docs/home/codingstyle.md`.

## Design And Verification Gates

- Complete the relevant design table and editable datapath diagram before RTL
  implementation for an instruction group.
- Implement Lab 1 group A before group B. Validate multiplier and divider as
  standalone modules before CPU integration.
- For normal RTL changes run `make lint` and a targeted `make trace TEST=...`.
- At instruction-group milestones run `make trace-all`.
- Do not claim Vivado or board validation when those steps were not run.
- The agent owns automated checks. The user owns physical programming and board
  observations.

## Git And Artifacts

- Keep `main` integrated; use short task branches rather than long-lived A/B
  branches.
- Preserve major milestones with tags.
- Do not commit downloaded course archives, waveform dumps, Vivado run
  directories, bitstreams, or caches.
- Curated timing, utilization, and power reports may be committed under
  `artifacts/` with the source commit and tool version recorded.
- Preserve unrelated user changes. Do not clean or rewrite upstream template
  whitespace as part of feature work.
