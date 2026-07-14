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
group-specific copies.

## CSV Semantics

The `demo` rows preserve the official course examples and must not be
normalized merely to match the rules below. These rules are mandatory for all
new or changed non-`demo` rows, including the cumulative `complete` row.

Common notation:

- An empty field means "not designed yet". A row with empty design fields is
  incomplete and cannot gate RTL implementation.
- `-` means the row places no semantic constraint on that field: the value or
  source is not observed while executing this instruction. It does not mean
  that the physical wire is disconnected, carries `X`, or lacks a deterministic
  RTL value.
- An explicit signal, symbol, or bit value means that the instruction requires
  that choice for correct architectural behavior.
- `|` lists alternative sources and is used only when combining instruction
  rows in the cumulative datapath row.
- Control symbols must match the macro names in
  `projects/single_cycle/src/rtl/defines.vh`, without the Verilog backtick.

For the datapath table, each column header names a destination input port and
the cell names its source. Read a populated cell as `cell -> column`; for
example, a value of `RF.rD1` under `ALU.A` means `RF.rD1 -> ALU.A`. Record a
source only when the instruction semantically consumes that input. Use `-`
when the input is irrelevant even if the live RTL always drives the physical
port. The cumulative `complete` row is the union of the required sources from
all completed instruction rows.

For the control-signal table:

- In `opcode`, `funct3`, and `funct7`, write every bit pattern required to
  recognize the instruction; `-` is a decode wildcard.
- Write an explicit control value whenever another value could change the
  architectural result, cause a side effect, or select a different completion
  path.
- Side-effect and progress controls must never use `-`. In the current
  single-cycle design this includes `npc_op`, `rf_we`, `ram_rop`, `ram_wop`,
  `is_mul`, and `is_div`; use their explicit inactive values when disabled.
- A function or mux control may use `-` only when its result is not observed.
  For example, `sext_op` is `-` for an R-type `add`, while `rf_wsel` must be
  explicit because that instruction enables register writeback.

Before RTL work, verify that the new instruction has no empty design fields,
the datapath and control rows describe the same behavior, and the `complete`
row includes every newly introduced input source. A `-` in the table remains a
don't-care in the design contract; synthesizable RTL must still drive the
corresponding control signal deterministically.

There is no continuously maintained `.drawio` source. If the final course
inspection still requires a graphical integrated datapath, produce it as a
milestone presentation artifact from the completed CSV tables and live RTL;
it is not an instruction-group implementation gate. Do not commit an untouched
copy of the downloaded course spreadsheet; the original is identified by
`materials/MANIFEST.md`.

Use `design/pipeline/` after Lab 2 is published. Keep design statements aligned
with live RTL rather than documenting intended behavior that the code no longer
implements.
