# Pipeline SoC PC5 Evidence

These files curate the routed pipeline SoC evidence generated from clean source
`14a05572ebb585f20a3c83341fb2abe6fb834b0d` with Vivado 2023.2 for
`xc7a35tcsg324-1`. The four candidates were built independently with:

```bash
just vivado-candidate-for pipeline c-test-0 bitstream
just vivado-candidate-for pipeline c-test-1 bitstream
just vivado-candidate-for pipeline c-test-2 bitstream
just vivado-candidate-for pipeline coremark bitstream
```

The generated evidence remains outside Git under
`/mnt/z/cpu-design-vivado/candidates/pipeline/<candidate>/`. Each
`stage5_evidence.json` independently passes `scripts/check_vivado_result.py`.
`candidate-manifest.tsv` is the hash bridge to the ignored COE, manifest,
selection, and bitstream files. The other summaries contain the common routed
results; all four candidates produced the same physical metrics.

## Review dispositions

- Timing closes at 50 MHz with positive setup and hold slack, zero total
  negative slack, and zero unconstrained paths.
- DRC reports no Error or Critical Warning. Its 42 Warning-level findings are
  `CHECK-3` x2, `REQP-1839` x20, and `REQP-1840` x20. They identify
  asynchronously reset AXI/interconnect address or state registers driving BRAM
  controls. Reset assertion invalidates transactions and reset release is
  synchronized, so these are accepted as non-blocking for PC5.
- Methodology reports three Warning-level findings: `LUTAR-1`, `XDCC-1`, and
  `XDCC-7`. The product intentionally asserts reset asynchronously on the board
  reset or PLL unlock and releases it synchronously. The duplicate input-clock
  constraints both specify the same 10 ns period.
- CDC reports only `CDC-3` Info x17 and `CDC-9` Info x1. These correspond to the
  marked two-stage switch/UART synchronizers and reset synchronizer.
- Power is a routed, vectorless estimate with Low confidence. It is not measured
  EGO1 power and must not be reported as such.

PC5 proves implementation, timing, candidate selection, and bitstream
provenance. EGO1 programming and behavior remain user-owned PC-U work.
