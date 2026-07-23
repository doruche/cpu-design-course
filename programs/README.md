# Board Programs

Assembly or C source is the source of truth for every board program. Never edit
machine-code COE content by hand.

Each program should provide a reproducible pipeline:

```text
source -> ELF -> BIN + disassembly -> COE
```

The final Lab 1 demonstration program belongs under `programs/lab1_demo/` once
its behavior is designed. Its generated ASM/disassembly and COE must come from
the same build and are exported for both the single-cycle and pipeline course
submission directories.

The untouched miniRV C_TEST seed archive is recorded under
`materials/lab2/c_test_rv_stu.tar.gz`. All six supplied programs are imported
under [`programs/c_test/`](c_test/README.md), including the deferred DDR and
LLAMA2 programs. Their source and supplied build inputs are tracked; the local
wrapper stages builds under the ignored `programs/c_test/build/` tree. Do not
edit the ignored archive or the copy inside the guide submodule.

The current WSL environment already provides RV32 and RV64 bare-metal GCC
toolchains. Choose the exact compiler flags, linker script, memory map, and COE
conversion only after the board-program contract is defined.
