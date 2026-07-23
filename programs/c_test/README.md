# miniRV C_TEST Programs

This directory contains the maintained working sources imported from the
course-provided miniRV Lab 2 C_TEST archive.

## Provenance

- Archive: `materials/lab2/c_test_rv_stu.tar.gz`
- SHA-256: `1b685c2334d2fac3d1f188ab1c420b670af3b37a3e3bb7748efe7ebc51612686`
- Pinned guide copy:
  `materials/instruction-site/docs/lab2-B/assets/c_test_rv_stu.tar.gz`
- Import date: 2026-07-23

The ignored archive remains the immutable provenance snapshot. The sources in
this directory are the canonical working copies for student changes. Keep the
repository private and do not redistribute these course materials.

All six supplied programs are retained:

| Directory | Purpose | Current status |
| --- | --- | --- |
| `0_uart_test/` | UART register and character I/O | Imported; TODOs not completed |
| `1_formatIO_test/` | `printf`/`scanf` I/O | Imported; TODOs not completed |
| `2_sort_test/` | Recursion and allocation | Imported; TODOs not completed |
| `3_ddr_test/` | DDR read/write test | Imported unchanged; deferred |
| `4_coremark/` | CoreMark workload | Imported unchanged |
| `5_llama2.c/` | LLAMA2 inference workload | Imported unchanged; deferred |

## Isolated Builds

Do not run the supplied compile scripts directly in the source directories;
they create temporary and generated files beside the source. Use this
directory's wrapper instead:

```bash
make list
make build TEST=0_uart_test
make build TEST=1_formatIO_test USE_DDR=1
make build TEST=4_coremark
```

The wrapper copies the selected source tree to `build/<test>/` and invokes the
supplied build there. All ELF, BIN, disassembly, COE, temporary linker scripts,
and other generated files therefore remain under the ignored `build/` tree.

The imported TODO-bearing tests are not expected to build successfully until
their Lab 2-B implementation gate. Importing a program or staging its build is
not evidence that it has passed compilation, simulation, or board validation.
