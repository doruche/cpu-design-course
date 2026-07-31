# Pipeline Product Provenance And Current Baseline

## Provenance

- Original source product: `projects/single_cycle/`
- Copied source commit: `c11ae43f8fe95d2de57e2f1021759d70c2e0321e`
- Copy refreshed: 2026-07-23
- Five-stage core commit: `63a5bb1`
- SoC fabric integration commit: `4103ee0`
- Merge commit on `main`: `842d558`
- PC5 clean product source: `14a05572ebb585f20a3c83341fb2abe6fb834b0d`
- PC-U board record: `895cef3`
- Physical-product milestone: `pipeline-soc-stage5`

The 2026-07-23 copy was only the starting point. `projects/pipeline/` is now an
independent canonical product containing the IF/ID/EX/MEM/WB core and its own
Cache/AXI/SoC source tree. It is not regenerated from `projects/single_cycle/`,
and changes must not be copied between products without product-local review.

## Current Product Baseline

The pipeline SoC product closed on 2026-07-30 with these evidence layers:

- PC4/PC5 fixed-container closure covered all five pipeline configurations,
  their 45 Trace cases, pipeline control, shared Cache/AXI/peripheral/fabric
  suites, pipeline C_TEST 0–2, and the CoreMark CRC system suite;
- four candidates built independently from clean source `14a05572` with
  Vivado 2023.2 for `xc7a35tcsg324-1`; each passed candidate/COE/bitstream
  provenance checks and 50 MHz implementation with setup WNS 3.912 ns, hold
  WHS 0.031 ns, zero negative slack, zero unconstrained paths, and no blocking
  DRC or methodology findings;
- user-owned EGO1 PC-U checks passed for C_TEST 0–2 and CoreMark using those
  four candidate hashes. The 700-iteration CoreMark run took 703,945,188
  cycles (14.07890376 s) and reported 49.7197 CoreMark and 0.9943 CoreMark/MHz
  with the expected algorithm CRCs.

PC6 changed documentation and provenance only. At the user's direction it did
not rerun automated or Vivado gates because no product source, test, workflow,
project, IP, constraint, or program changed after the PC5 evidence source.
Current claims therefore reuse the recorded PC4/PC5 evidence and PC-U board
observations; they are not new PC6 runtime results. Official IP topology,
report content, final assembly/COE, and submission packaging remain Pending.
