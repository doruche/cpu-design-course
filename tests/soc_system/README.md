# CPU-driven SoC smoke

`smoke.S` is a repository-owned verification program, not a course C_TEST
image. `just system soc-smoke` builds it for RV32IM into the ignored
`.cache/system/soc-smoke/` directory and runs `soc_system_tb.sv` against the
canonical single-cycle product RTL and the pinned behavioral AXI RAM.

The self-checking test covers normal cached memory plus switch, LED,
seven-segment, UART, and timer MMIO. It is an RTL system simulation and does
not replace Vivado implementation, a bitstream, or physical-board checks.
