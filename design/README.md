# Design Artifacts

Design artifacts are implementation gates, not disposable report decorations.

For the single-cycle CPU, complete work in this order:

1. Group A rows in both CSV tables, plus the cumulative `complete` datapath row.
2. Group A RTL and Trace validation.
3. Group B rows in both CSV tables, plus the updated cumulative `complete` row.
4. Standalone multiplier and divider designs and tests.
5. Group B RTL and Trace validation.
6. Full Basic Trace and the final course-inspection artifacts.

The two continuously maintained design sources are:

- [`single_cycle/datapath.csv`](single_cycle/datapath.csv), one flattened row
  per instruction plus a cumulative `complete` row;
- [`single_cycle/control_signals.csv`](single_cycle/control_signals.csv), one
  row per instruction with its decode fields and controller outputs.

Both files are UTF-8, comma-delimited CSV. Keep the template instructions and
new instruction groups in one cumulative table rather than creating parallel
group-specific copies. An empty field means "not designed yet"; `-` means the
input or control is intentionally unused for that instruction. Use `|` inside a
field to list alternative sources in the cumulative datapath row. Control
symbols must match the macro names in
`projects/single_cycle/src/rtl/defines.vh`, without the Verilog backtick.

There is no continuously maintained `.drawio` source. If the final course
inspection still requires a graphical integrated datapath, produce it as a
milestone presentation artifact from the completed CSV tables and live RTL;
it is not an instruction-group implementation gate. Do not commit an untouched
copy of the downloaded course spreadsheet; the original is identified by
`materials/MANIFEST.md`.

Use `design/pipeline/` after Lab 2 is published. Keep design statements aligned
with live RTL rather than documenting intended behavior that the code no longer
implements.
