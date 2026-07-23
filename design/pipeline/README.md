# Pipeline Design Contracts

This directory is the Lab 2-A design gate for the pipeline product. It is
authoritative for stage allocation and pipeline control, while the ISA-level
behavior contract remains in `design/single_cycle/`. Do not copy the
single-cycle instruction rows here.

Complete `stage_registers.csv` before editing pipeline RTL. Complete the
relevant rows in `flow_control.csv` and `hazards.csv` before implementing each
corresponding control mechanism. Keep every row synchronized with live RTL.

The current files describe the planned five-stage baseline only; they do not
claim that the copied pipeline product has implemented any pipeline behavior.

