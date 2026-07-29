# Curated Build Evidence

Vivado build directories are generated and ignored. This directory is only for
small, reviewable evidence needed by the final report, such as:

- post-implementation timing summary;
- utilization report;
- power report;
- a short metadata file containing source commit, Vivado version, target part,
  clock configuration, and program image hash.

Use separate `single_cycle/` and `pipeline/` milestone directories when those
reports exist. Do not commit bitstreams, ILA captures, complete Vivado logs, or
raw run directories here.

## Evidence index

- `pipeline/`: PC5 clean routed evidence for the four pipeline C_TEST/CoreMark
  candidates, including hash provenance, timing, utilization, power estimate,
  and warning review dispositions. EGO1 board observations remain Pending.
