# Design Artifacts

Design artifacts are implementation gates, not disposable report decorations.

For the single-cycle CPU, complete work in this order:

1. Group A datapath and control-signal tables.
2. Group A RTL and Trace validation.
3. Group B datapath and control-signal tables.
4. Standalone multiplier and divider designs and tests.
5. Group B RTL and Trace validation.
6. Complete integrated datapath diagram and full Basic Trace.

Store editable sources under `design/single_cycle/` as they are created. Small
completed spreadsheets may be tracked. Track the datapath diagram as `.drawio`
and export a PDF for course inspection. Do not commit an untouched copy of the
downloaded course template; the original is identified by
`materials/MANIFEST.md`.

Use `design/pipeline/` after Lab 2 is published. Keep design statements aligned
with live RTL rather than documenting intended behavior that the code no longer
implements.
