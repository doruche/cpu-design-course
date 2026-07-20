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

## Lab 1 Download Checksums

| File | SHA-256 |
| --- | --- |
| `Lab1-PPT-单周期CPU设计-1（示例代码仿真）.pdf` | `1e5e4d346e7ea64d28fcee856dcf1e5fead53fc7c408f9000c5cf248fd2cb560` |
| `Lab1-PPT-单周期CPU设计-2（取指、译码）.pdf` | `e834ca4a5809a1b1e9a3d1fa6a18cb7c02e782e17f7a9c3574047ea74f76b52f` |
| `Lab1-PPT-单周期CPU设计-3（执行、访存、写回）.pdf` | `e88eed3e5875139a3bebfe22e0ea1f198398f1e87a02a536916456424fb5a7ee` |
| `Theory1-PPT-单周期CPU设计.pdf` | `98fa7170884129dae62549f67347d04a34a59fb057c3b496d43c52c2da4a77f1` |
| `miniLA_basic_ego1.zip` | `88c0cb3f72b820c080e2881fd6b4de3b4442c395e68420e104aab9257adad8fe` |
| `miniLA_basic_minisys.zip` | `7d358d6c370f77356bb5744587ac6791493e7a1e8e60f0860113a26808fba387` |
| `miniLA指令速查表.xlsx` | `894d3d8657ed0e7803b09692d62314bf3688222a028331f29b16c4ab13031d5b` |
| `miniRV_basic_ego1.zip` | `8169b64de631c22d7668185cbd9fb22f288519d6267f4f314a29cf420c3d3570` |
| `miniRV_basic_minisys.zip` | `097c8081d0a16540df787849d816b61985d07fa5534c536938534119e5e8707b` |
| `miniRV指令速查表.xlsx` | `987d68739f4b7431263795f2f6585ccae7324b5cb52ab455110f11f334fc92c4` |
| `数据通路表、控制信号取值表_miniLA - 模板.xlsx` | `1d9c9a5559547cba723b6fb1e19ddbdeb3f7ecdd133b0e8c64ef604452f100df` |
| `数据通路表、控制信号取值表_miniRV - 模板.xlsx` | `bff90e68f33b0d2ad5537f382c08efe3b19c0d0dfd21c230ecd5b7e53374ec13` |

## Lab 2 Local Material Set

`materials/lab2/` is ignored by Git. For the selected miniRV + EGO1 path it
contains local snapshots of the guide assets that are used outside the guide
itself:

| File | SHA-256 | Purpose | Source in pinned guide |
| --- | --- | --- | --- |
| `bin2coe-guide.py` | `faafd96a730cb28b170c9ad9f96f7c9d3d67c614311060007b89864f28bf9cc4` | Unmodified guide snapshot of the BIN-to-COE converter | `docs/lab2-A/assets/bin2coe.py` |
| `bin2coe.py` | `99bad5a69fe42450a9df163028a864cf5ffc2378bad9b3907c6dfcb119dd6254` | UTF-8 runnable copy of the guide converter | Derived from `bin2coe-guide.py` |
| `c_test_rv_stu.tar.gz` | `1b685c2334d2fac3d1f188ab1c420b670af3b37a3e3bb7748efe7ebc51612686` | miniRV I/O, DDR, CoreMark, and LLAMA2 test programs | `docs/lab2-B/assets/c_test_rv_stu.tar.gz` |
| `lab2_IOtest_miniRV_ego1.bit` | `fcbbfe3815c278050f4fdf51585da8863c90a53bf55818aa3879b3c2b26130ac` | User-owned EGO1 validation of completed C_TEST programs | `docs/lab2-B/assets/lab2_IOtest_miniRV_ego1.bit` |

These copies are convenience inputs, not a second course-contract source. When
the guide pin changes, compare them with the listed source files and refresh
the snapshots and hashes together.

The guide's converter is GB18030 text without a Python encoding declaration,
so Python 3 rejects it before execution. Lab 2-B also links to the nonexistent
`docs/lab2-B/assets/bin2coe.py`. Preserve `bin2coe-guide.py` byte-for-byte for
provenance and use the UTF-8 `bin2coe.py` copy locally.

The following guide assets are conditional and are not copied for the selected
path:

- miniLA C_TEST and test bitstreams;
- Minisys I/O bitstreams, DDR constraint, and DDR test bitstream, which are
  needed only if the LLAMA2/Minisys stretch path is opened.

The course download center had no Lab 2 directory on 2026-07-20. The guide
requires both Lab 2 streams to start by copying the completed Lab 1 project, so
there is currently no separate Lab 2 Vivado template to archive. When the
download center publishes Lab 2 course slides or the final report template,
download them into `materials/lab2/` and add their exact hashes here. The
ICache/DCache source required by Lab 2-B is prior student work from Computer
Organization Lab 3, not an attachment supplied by this guide.

## Pinned Repositories

| Path | Branch | Commit | Purpose |
| --- | --- | --- | --- |
| `cdp-tests/` | `miniRV` | `50a818278e9a60d304521c4b16980211b0162014` | Trace framework with repaired `start` test |
| `materials/instruction-site/` | `main` | `e2748d2b7cd765a19146dff1355cc842ac68fe64` | Official course guide with Lab 2-A and Lab 2-B |

The parent repository pins these exact commits as Git submodules. Update guide
commits explicitly after reviewing their diff; do not automatically track the
latest upstream commit.
