# Verilator Lint Baselines

`verilator-single_cycle.vlt` contains exact waivers generated from the untouched
official Lab 1 template with Verilator 5.051. The waivers make the imported
baseline green without disabling warning classes globally.

Treat them as temporary debt:

- remove a waiver when the corresponding template TODO or width issue is fixed;
- do not add a waiver merely to make new code pass;
- review every new warning and fix its cause unless there is a documented
  hardware reason for a narrow waiver.

Create a separate product-specific baseline when `projects/pipeline/` is
created; do not reuse the single-cycle file blindly.
