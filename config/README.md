# Build Configurations And Lint Baselines

`build-configs.tsv` is the single machine-readable owner for the stable product
verification configurations. `just show-config <name>` resolves each row into
its product, topology, memory model, Cache mode, backend, compiler defines,
canonical RTL source set, and artifact directory. Unknown names and invalid
tuples are rejected before a backend runs.

Stable names are `single-basic`, `single-axi-direct-bypass`,
`single-axi-direct-cache`, `single-soc-bypass`, `single-soc-cache`, and
`pipeline-basic`. Trace commands serialize access to the vendored framework's
shared `tests/cdp/obj_dir`.

## Verilator Lint Baselines

`verilator-single_cycle.vlt` contains exact waivers generated from the untouched
official Lab 1 template with Verilator 5.051. The waivers make the imported
baseline green without disabling warning classes globally.

Treat them as temporary debt:

- remove a waiver when the corresponding template TODO or width issue is fixed;
- do not add a waiver merely to make new code pass;
- review every new warning and fix its cause unless there is a documented
  hardware reason for a narrow waiver.

Create a separate product-specific baseline when `projects/pipeline/` is
created; do not reuse the single-cycle file blindly. The initial pipeline
baseline is copied from the Lab 1 template only to make the product buildable;
new pipeline warnings must be fixed rather than added as waivers.
