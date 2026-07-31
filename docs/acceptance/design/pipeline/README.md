# Pipeline Design Contracts

This directory is the Lab 2-A design gate for the pipeline product. It is
authoritative for stage allocation and pipeline control, while the ISA-level
behavior contract remains in `../single_cycle/`. Do not copy the
single-cycle instruction rows here.

Complete `stage_registers.csv` before editing pipeline RTL. Complete the
relevant rows in `flow_control.csv` and `hazards.csv` before implementing each
corresponding control mechanism. Keep every row synchronized with live RTL.

The current files describe the live five-stage implementation merged at
`842d558`: its four stage-register groups, forwarding and load-use rules, and
the reset/stall/flush priority. They are maintained contracts, not historical
plans; any later semantic change must update the relevant rows before RTL.
