# Pipeline Product Baseline

- Source project: `projects/single_cycle/`
- Source commit: `c11ae43f8fe95d2de57e2f1021759d70c2e0321e`
- Refreshed: 2026-07-23
- Scope: all tracked files under the source project
- Status: exact tracked project copy; pipeline RTL has not started

This file records provenance only. The canonical implementation is the project
tree itself. Ignored Vivado-generated products are intentionally excluded, and
validation results must be reported from the current checkout.

## Refresh Validation

On 2026-07-23, before pipeline RTL work started:

- `make lint PRODUCT=pipeline` passed.
- `make trace-all PRODUCT=pipeline` passed all 45 Basic Trace cases, including
  `start`.
- `make check-products` passed lint and all 45 Basic Trace cases for both
  `single_cycle` and `pipeline`.
- `make vivado-stage PRODUCT=pipeline` regenerated the disposable Windows
  staging tree.

Vivado simulation, synthesis, implementation, bitstream generation, and board
validation were not run for this refresh.
