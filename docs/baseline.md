# Official Template Verification Baseline

Baseline date: 2026-07-13

Environment:

- Verilator 5.051 devel, revision `v5.050-59-gdde8de0a0`
- `tests/cdp` commit `af81241848cdbbf4f1af3d1b6bb83ec3b6b7968f`
- `miniRV_basic_ego1.zip` SHA-256
  `8169b64de631c22d7668185cbd9fb22f288519d6267f4f314a29cf420c3d3570`

The canonical project passes these Trace cases without changing course RTL:

```text
addi ori slli lw beq bne jal
```

The guide states that the template implements eight instructions: `addi`,
`ori`, `slli`, `lui`, `lw`, `beq`, `bne`, and `jal`. Seven standalone cases are
green because `lui.bin` also uses `srai` at PC `0x18` to check a LUI result, and
`srai` is an unimplemented group A instruction in the original template. The
observed mismatch is therefore:

```text
REFERENCE: PC=0x00000018, WReg=1, WBValue=0xfffff800
MYCPU:     PC=0x0000001c, WReg=7, WBValue=0xfffff800
```

The passing `lw` case executes LUI as a prerequisite and provides baseline
coverage for the template LUI implementation. The dedicated `lui` case should
be added to the passing set after group A implements `srai`.

The same `lui` failure was reproduced both with canonical RTL passed directly
to Verilator and with the course-documented copy of RTL under `mySoC`. It is not
caused by the repository's external-source Trace integration.
