# Pipeline Product Provenance And Current Baseline

## Provenance

- Original source product: `projects/single_cycle/`
- Copied source commit: `c11ae43f8fe95d2de57e2f1021759d70c2e0321e`
- Copy refreshed: 2026-07-23
- Five-stage core commit: `63a5bb1`
- SoC fabric integration commit: `4103ee0`
- Merge commit on `main`: `842d558`

The 2026-07-23 copy was only the starting point. `projects/pipeline/` is now an
independent canonical product containing the IF/ID/EX/MEM/WB core and its own
Cache/AXI/SoC source tree. It is not regenerated from `projects/single_cycle/`,
and changes must not be copied between products without product-local review.

## Current Automated Baseline

The 2026-07-29 post-merge assessment of `842d558` established:

- lint and all 45 Trace cases pass for each of the five pipeline configurations;
- the shared cache, AXI master, peripheral and fabric suites pass;
- the repository records a one-iteration CoreMark RTL run from the feature
  branch, but the post-merge host rerun stopped at a soft-float/libgcc ABI
  mismatch before RTL simulation.

The pipeline C_TEST suites, Vivado physical-product path, 50 MHz timing,
implementation, bitstream and EGO1 board validation are not closed. Validation
must always be reported from the current checkout; this provenance file is not
runtime evidence.
