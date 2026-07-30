# 流水线 SoC 官方截图证据合同

## 范围

当前验收只需要实验二流水线 SoC 的三张 Post-Implementation 截图：Utilization、Power
和 Timing。实验一 ASM/COE、单周期截图、报告正文/PDF 和最终提交包不在本合同内。

固定版本指导书 `materials/instruction-site/docs/home/submit.md` 要求实现完成后读取
Post-Implementation 的 Timing、Utilization 和 Power。用户进一步指定了三张图必须显示
的字段。本文件只冻结来源、文件名、画面内容和核对值；AR2 不生成或代替 GUI 截图。

## 冻结来源

| 字段 | 冻结值 |
| --- | --- |
| product / candidate | `pipeline` / `coremark` |
| canonical source commit | `14a05572ebb585f20a3c83341fb2abe6fb834b0d` |
| staged project | `Z:\\cpu-design-vivado\\pipeline\\miniRV.xpr` |
| implementation run | `impl_1`，routed / Post-Implementation |
| Vivado / part | 2023.2 / `xc7a35tcsg324-1` |
| input / product clock | 100 MHz / 50 MHz |
| bitstream SHA-256 | `36c3f95eaf4faa6b9bd609e783423057af4bee110343f3bce71a2362ec97c6ab` |
| COE SHA-256 | `aaf7c184d27c4c2afeacae8c22f807b75fa1ea584295d16bac344bf37671bae3` |
| evidence JSON | `Z:\\cpu-design-vivado\\pipeline\\artifacts\\stage5_evidence.json` |

当前仓库的 bitstream 入口要求显式候选。冻结 run 的原生成命令是：

```bash
just vivado-candidate-for pipeline coremark bitstream
```

`just vivado pipeline bitstream` 不是当前可执行入口：`scripts/vivado.sh` 会因没有显式
candidate 而拒绝生成 bitstream。截图时不需要重新 stage 或重跑实现；直接打开上表工程和
现有 `impl_1`，避免 `rsync --delete` 改写当前 Windows staging。若将来确需重跑，新的
source commit、报告和 hash 必须作为新 run 重新审核，不能沿用本合同的旧绑定。

## 截图文件合同

截图采用 PNG，保持操作系统原始截图分辨率，不缩放、不转码；不规定固定像素尺寸，但
表格标题、字段名、数值和单位必须在 100% 显示比例下清晰可读。允许裁去无关窗口区域，
不得裁掉用于识别报告类型的标题或本表要求的字段。AR4 归档路径为
`artifacts/acceptance/screenshots/`。

| 文件名 | Vivado 页面 | 画面必须包含 | 与 raw report 核对值 |
| --- | --- | --- | --- |
| `pipeline-post-impl-utilization.png` | Open Implemented Design → Reports → Report Utilization | Slice LUTs、Slice Registers、Block RAM Tiles、DSPs 汇总表 | 4101 / 20800（19.72%）；2241 / 41600（5.39%）；37.5 / 50（75.00%）；0 / 90（0.00%） |
| `pipeline-post-impl-power.png` | 同一 Implemented Design → Reports → Report Power | Total On-Chip Power、Dynamic、Device Static 及 On-Chip Components 各部分 | 0.189 W total；0.115 W dynamic；0.074 W static；overall confidence `Low` |
| `pipeline-post-impl-timing.png` | 同一 Implemented Design → Reports → Timing → Report Timing Summary | Design Timing Summary 的 WNS、TNS、WHS、THS、failing endpoints 和约束满足结论 | WNS 3.912 ns；TNS 0.000 ns；WHS 0.031 ns；THS 0.000 ns；setup/hold failing endpoints 均为 0 |

Timing 图必须能看出 setup 与 hold slack 均为正、TNS/THS 为 0，并显示
`All user specified timing constraints are met` 或同义的无违例结论。Power 图若一个视图
无法同时容纳 Summary、On-Chip Components 和 Confidence，可在不改变文件名和来源 run
的前提下扩大报告区域；Low confidence 至少必须记录在 AR4 manifest 和交接说明中。

## 原始证据绑定

| 文件 | SHA-256 |
| --- | --- |
| `pipeline/artifacts/stage5_evidence.json` | `a8040c2ff9b16b96f6404a4abe4b6a11e0d4b84da282fe38b3db33d7c65afb0f` |
| `pipeline/artifacts/build_facts.tsv` | `377259e645dd2dd242244c9182436688ac7f6e37acb94f711fdddb668acfe570` |
| `pipeline/artifacts/timing_summary.rpt` | `88d434f3e2c56a44aedfb8085aa5daa19994ee7790ae949fb3d098605db07c82` |
| `pipeline/artifacts/utilization.rpt` | `bc5aae538719c11928015f54730fe6c5e095bf40c7fc4d4763ef3675191d4eb8` |
| `pipeline/artifacts/power.rpt` | `3341fa7bd48b9c4a4e9b3ae6ea0060a2b06b04b5535f637af9b71fb1314235f6` |

以上相对路径均以 `Z:\\cpu-design-vivado\\` 为根。仓库内
`artifacts/pipeline/{timing-summary.tsv,utilization-summary.txt,power-summary.txt}` 是同一组
数值的精选摘要，不替代 GUI 截图或原始 `.rpt`。

## AR4 接收判据

- 三个 PNG 文件名、来源 run 和必需字段全部符合本合同；
- 截图数值与上述 raw report、evidence JSON 和仓库精选摘要一致；
- Timing 无违例，Power 明确作为 routed vectorless estimate 且 confidence 为 Low；
- AR4 manifest 记录三个 PNG 和五个 raw evidence 文件的 SHA-256、owner、用途和来源；
- 任一图来自 Synthesized Design、其他 candidate、其他 implementation run，或数值/来源
  无法判断时，停止 AR4，不通过裁图或改文案掩盖差异。
