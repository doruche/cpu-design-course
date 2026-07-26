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
| `0_uart_test/` | UART register and character I/O | Stage 4 implemented |
| `1_formatIO_test/` | `printf`/`scanf` I/O | Stage 4 implemented |
| `2_sort_test/` | Recursion and allocation | Stage 4 implemented |
| `3_ddr_test/` | DDR read/write test | Imported unchanged; deferred |
| `4_coremark/` | CoreMark workload | Imported unchanged |
| `5_llama2.c/` | LLAMA2 inference workload | Imported unchanged; deferred |

## Repository Builds

Do not run the supplied compile scripts directly in the source directories;
they create temporary and generated files beside the source. The only public
entries are the root Just recipes:

```bash
just program c-test-0
just program c-test-1
just program c-test-2
```

The tracked default student ID is `2024311488`, defined once in
`runtime/c_test_identity.h`. `STUDENT_ID` remains an explicit 8-to-12 digit
override, for example `STUDENT_ID=2024311488 just program c-test-0`. Both the
default and a valid override produce candidate manifests.

Outputs are isolated under `.cache/programs/c_test/<test>/`:

- `.elf` and `.dump` preserve the audited RV32IM/ILP32 program and disassembly;
- `.raw.bin` is the headerless behavioral-memory image;
- `.coe` contains the same payload as 32-bit words;
- `.uart.bin` adds the course downloader's word-count header;
- `.manifest` records identity status, source/tool versions, sections, sizes,
  hashes, memory bounds, and the cross-image word comparison.

The repository-owned freestanding runtime under `runtime/` avoids inheriting
the host toolchain's floating-point multilib ABI. It owns startup/BSS clearing,
the bounded heap, C_TEST formatting/parsing, UART polling, and the timer's
high-low-high snapshot. The retained `Makefile` and supplied `compile*.sh` files
are provenance/reference inputs, not public build interfaces.

Run deterministic software and CPU-driven RTL checks with:

```bash
just unit c-test-software
just system c-test-0
just system c-test-1
just system c-test-2
```

These checks do not replace the user-owned course-bitstream test or validate a
repository-generated FPGA bitstream.
