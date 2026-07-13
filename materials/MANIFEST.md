# Course Material Manifest

The downloaded course materials are intentionally kept out of this Git
repository. The course guide states that the materials are restricted to the
2026 summer course and must not be redistributed.

## Selected Configuration

- Board: EGO1 (`xc7a35tcsg324-1`)
- ISA: miniRV
- Vivado project: `miniRV_basic_ego1.zip`
- Required Vivado version: 2023.2
- Extracted project: `projects/single_cycle/`

## Download Checksums

| File | SHA-256 |
| --- | --- |
| `Theory1-PPT-单周期CPU设计.pdf` | `98fa7170884129dae62549f67347d04a34a59fb057c3b496d43c52c2da4a77f1` |
| `miniLA_basic_ego1.zip` | `88c0cb3f72b820c080e2881fd6b4de3b4442c395e68420e104aab9257adad8fe` |
| `miniLA_basic_minisys.zip` | `7d358d6c370f77356bb5744587ac6791493e7a1e8e60f0860113a26808fba387` |
| `miniLA指令速查表.xlsx` | `894d3d8657ed0e7803b09692d62314bf3688222a028331f29b16c4ab13031d5b` |
| `miniRV_basic_ego1.zip` | `8169b64de631c22d7668185cbd9fb22f288519d6267f4f314a29cf420c3d3570` |
| `miniRV_basic_minisys.zip` | `097c8081d0a16540df787849d816b61985d07fa5534c536938534119e5e8707b` |
| `miniRV指令速查表.xlsx` | `987d68739f4b7431263795f2f6585ccae7324b5cb52ab455110f11f334fc92c4` |
| `数据通路表、控制信号取值表_miniLA - 模板.xlsx` | `1d9c9a5559547cba723b6fb1e19ddbdeb3f7ecdd133b0e8c64ef604452f100df` |
| `数据通路表、控制信号取值表_miniRV - 模板.xlsx` | `bff90e68f33b0d2ad5537f382c08efe3b19c0d0dfd21c230ecd5b7e53374ec13` |

## Pinned Repositories

| Path | Branch | Commit | Purpose |
| --- | --- | --- | --- |
| `cdp-tests/` | `miniRV` | `af81241848cdbbf4f1af3d1b6bb83ec3b6b7968f` | Trace framework and golden model |
| `materials/instruction-site/` | `main` | `ef64ec455864ac396cfae8895f5505b0133d8c72` | Official course guide |

The parent repository pins these exact commits as Git submodules. Update the
guide explicitly when Lab 2 is released; do not automatically track the latest
upstream commit.
