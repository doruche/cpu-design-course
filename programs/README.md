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

The current WSL environment already provides RV32 and RV64 bare-metal GCC
toolchains. Choose the exact compiler flags, linker script, memory map, and COE
conversion only after the board-program contract is defined.
