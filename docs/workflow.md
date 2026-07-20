# Development Workflow

## Goal And Product Model

The repository targets the complete course outcome as a solo project. The
official two-person task split is retained as sequential work streams:

- Lab 1: group A, group B, then the complete single-cycle CPU.
- Lab 2 pipeline stream: ideal pipeline, hazards, stalls, and forwarding.
- Lab 2 SoC stream: caches, AXI, C interfaces, and I/O.
- Integration: a pipeline SoC running CoreMark on EGO1 first. LLAMA2 requires
  the Minisys DDR path and remains a stretch target after the required EGO1
  path is complete.

Source is organized by final product rather than course chronology:

- `projects/single_cycle/` starts as the Lab 1 CPU and later becomes the
  single-cycle SoC.
- `projects/pipeline/` is created from the completed Lab 1 design and remains an
  independently buildable pipeline product.

The Lab 1 state is preserved with a tag; the single-cycle product directory can
continue receiving Lab 2 SoC work.

## Truth Boundaries

| Concern | Canonical location | Derived locations |
| --- | --- | --- |
| Single-cycle HDL | `projects/single_cycle/src/rtl/` | Trace build, submission export, Windows staging |
| Pipeline HDL | `projects/pipeline/src/rtl/` | Trace build, submission export, Windows staging |
| Board configuration | Product `.xpr`, XCI, XDC, COE, Tcl | Windows staging |
| Single-cycle design | `design/single_cycle/*.csv` | Milestone-only presentation diagram |
| Course behavior | `materials/instruction-site/` submodule | Local links and short decision notes |
| Golden verification | `cdp-tests/` submodule | Generated executable and waveforms |
| Board program | `programs/<name>/` source | ELF, BIN, disassembly, COE |

Copies are allowed only as generated outputs. A failure discovered in a derived
directory must be fixed in its canonical owner and regenerated.

## Fast WSL Loop

1. Update both single-cycle CSV tables when the datapath/control contract
   changes. Complete the relevant instruction rows and cumulative `complete`
   datapath row under the rules in [`design/README.md`](../design/README.md)
   before editing RTL.
2. Edit canonical RTL.
3. Run `make lint`.
4. Run a targeted Trace case with `make trace TEST=<case>`.
5. Inspect the generated VCD and matching `cdp-tests/asm/<case>.dump` on failure.
6. Run the relevant module test before integrating high-risk state machines.
7. Run `make trace-all` at a feature-group milestone.

Trace compiles canonical RTL directly. `cdp-tests/mySoC/` remains the untouched
upstream placeholder.

## Vivado Loop

Vivado is a lower-frequency FPGA backend gate, not the interactive editor:

1. Canonical WSL project files are copied one-way to a disposable Windows
   staging directory.
2. Vivado 2023.2 opens the tracked official `.xpr` in project mode.
3. Repository Tcl runs synthesis, implementation, reports, and bitstream
   generation.
4. Selected reports are copied back with source revision metadata.
5. Any fix is made in WSL and restaged.

Run synthesis after changes to top-level wiring, reset, clocking, memory
interfaces, constraints, IP, or large datapaths. Run implementation and timing
at product milestones and before board tests. The Vivado GUI remains available
for IP inspection, timing schematics, Hardware Manager, and ILA debugging.

Track the official `.xpr` initially. Do not replace it with a from-scratch
project-generation Tcl flow until the official project has completed a clean
Windows staging build and there is concrete evidence that `.xpr` state causes a
problem.

## Git Workflow

- `main` is the continuously integrated product history.
- Use short-lived branches for bounded tasks; do not keep permanent group A and
  group B variants.
- `upstream-lab1-template` identifies the curated official template import.
- `lab1-complete` identifies the complete Lab 1 CPU after full Trace and Vivado
  synthesis/implementation. Board validation is not part of that Lab 1 tag.
- Tag later pipeline, SoC, and board milestones independently.
- Keep the repository private.
- Update submodule commits explicitly after reviewing their changes; do not
  automatically follow upstream branches.

## Validation And Evidence

| Change level | Required validation |
| --- | --- |
| Existing RTL logic | Lint and targeted Trace |
| Instruction group | Module tests as applicable and full Basic Trace |
| Clock/reset/IP/top-level | Trace plus Vivado synthesis |
| Product milestone | Full Trace, implementation, timing, utilization, power |
| Release/submission | Exported-tree Trace, bitstream, and user-observed board test |

Generated runs and waveforms are disposable. Curated text reports used by the
final report belong under `artifacts/`; each report set records the source
commit, Vivado version, clock configuration, and program image.

## Lab 2 Gate Order

The published Lab 2 guide fixes two parallel course work streams that converge
into the final pipeline SoC. In this solo repository they are performed as
bounded sequential gates:

1. Preserve the completed Lab 1 state with a milestone tag before either Lab 2
   product changes it.
2. Create `projects/pipeline/` from the completed single-cycle project and add a
   product-specific lint baseline. Implement an ideal five-stage pipeline and
   verify it with independent, non-memory, non-multiply/divide programs.
3. Add RAW hazard detection, predict-not-taken control handling, pipeline
   stalls, and forwarding. Memory and multiply/divide operations must obey
   their multi-cycle completion handshakes. Finish this stream with all 45
   Trace cases, including `start`.
4. Evolve `projects/single_cycle/` into the single-cycle SoC. Integrate the
   ICache/DCache interfaces, implement the state-machine AXI master, bridge,
   shared memory, and the required switch, LED, seven-segment, UART, and timer
   I/O interfaces.
5. Bring up AXI first with caches disabled, then enable and verify both caches.
   Complete the miniRV C_TEST programs, run the user-owned EGO1 board checks,
   and finish the single-cycle stream with AXI Trace.
6. Integrate the pipeline core into the verified SoC, rerun AXI Trace, and run
   CoreMark on EGO1. The final pipeline SoC must meet at least 50 MHz with no
   timing violation; the single-cycle SoC minimum is 25 MHz.

The guide assumes reusable ICache and DCache modules from the earlier Computer
Organization Lab 3. Those sources are not included in this repository or in
the Lab 2 guide assets, so their provenance and interface compatibility must be
resolved before the single-cycle SoC cache gate. The existing Lab 1 EGO1
project is the starting template for both streams; no separate Lab 2 Vivado
template is required by the guide.

Before the pipeline product is created, extend the root build configuration
with a `pipeline` lint baseline. Before AXI integration, split Basic and AXI
Trace/lint source profiles so each product is checked against the correct
memory model without changing `cdp-tests/`.
