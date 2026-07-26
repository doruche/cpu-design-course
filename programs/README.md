# Board Programs

Assembly or C source is the source of truth for every board program. Never edit
machine-code COE content by hand.

Each program should provide a reproducible pipeline:

```text
source -> ELF + disassembly -> raw BIN + COE + UART package + manifest
```

The final Lab 1 demonstration program belongs under `programs/lab1_demo/` once
its behavior is designed. Its generated ASM/disassembly and COE must come from
the same build and are exported for both the single-cycle and pipeline course
submission directories.

The untouched miniRV C_TEST seed archive is recorded under
`materials/lab2/c_test_rv_stu.tar.gz`. All six supplied programs are imported
under [`programs/c_test/`](c_test/README.md), including the deferred DDR and
LLAMA2 programs. Their source and supplied build inputs are tracked. Stage 4
C_TEST 0～2 builds are exposed only through
`just program c-test-0|c-test-1|c-test-2` and place all outputs under
`.cache/programs/c_test/`. Do not edit the ignored archive or the copy inside
the guide submodule.

The C_TEST Stage 4 runtime freezes RV32IM/ILP32, the three 50 KiB memory regions,
and distinct raw/COE/UART consumers. Other board programs must define their own
contract before selecting those inputs.
