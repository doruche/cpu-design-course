# C_TEST verification

`just unit c-test-software` compiles the maintained helper logic for the host
and checks UART FIFO polling, formatted output/input, bounded strings, coherent
timer rollover handling, quicksort, and heap bounds.

`just system c-test-0|c-test-1|c-test-2` builds the matching RV32IM image and
runs it from reset PC `0x00000000` through the canonical single-cycle product.
The explicit `just system pipeline-c-test-0|pipeline-c-test-1|pipeline-c-test-2`
suites run the same image and oracle through `pipeline-soc-cache`. Both routes
include enabled I/D caches, the AXI master, product fabric, behavioral memory,
and MMIO. The testbench drives and decodes only the top-level UART `rx`/`tx`
pins for program interaction. Internal buses are observed for protocol
assertions but are not used to inject program state.

The fixed Trace RAM is overridden only at the testbench instance to 65,536
32-bit words (256 KiB), satisfying the C_TEST `0x00025800` address range while
remaining a power of two. UART uses a simulation-only four-clock 8N1 bit time;
the register and FIFO semantics are unchanged, and `just system soc-smoke`
retains the ordinary 50 MHz / 115200-baud model.

Each run writes a transcript and requires a deterministic PASS from
`scripts/check-c-test-transcript.py`. These suites prove RTL-system behavior;
they do not prove Vivado implementation, a product bitstream, or board I/O.
