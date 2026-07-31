# 流水线 SoC 截图证据交接

## 交接范围

本交接只包含实验二流水线 SoC 的三张 Post-Implementation 截图及其来源证明，不包含
实验一、单周期材料、报告正文/PDF、最终提交包或教师验收结论。

三张必交图均由用户从 Vivado 2023.2 的
`Z:\\cpu-design-vivado\\pipeline\\miniRV.xpr` 采集，分辨率为 2232×1416，来源为
`pipeline/coremark` routed `impl_1`。冻结 source commit 是
`14a05572ebb585f20a3c83341fb2abe6fb834b0d`，器件为 `xc7a35tcsg324-1`，产品时钟为
50 MHz。逐文件 hash 和外部 raw evidence 路径见
`artifacts/acceptance/manifest.tsv`。

## 三张必交图

| 图 | 视觉核验 | 结论 |
| --- | --- | --- |
| `pipeline-post-impl-utilization.png` | Project Summary 明确选择 Post-Implementation Table；LUT 4101/20800（19.72%）、FF 2241/41600（5.39%）、BRAM 37.50/50（75.00%） | PASS；Vivado GUI 省略零 DSP 行，由同 run raw report 的 DSPs 0/90（0.00%）补充 |
| `pipeline-post-impl-power.png` | Implemented Design Power Summary；Total 0.189 W、Dynamic 0.115 W、Device Static 0.074 W，显示各部分占比和 confidence Low | PASS；只能表述为 routed vectorless estimate，不是开发板实测功耗 |
| `pipeline-post-impl-timing.png` | Implemented Design Timing Summary；WNS 3.912 ns、TNS 0.000 ns、WHS 0.031 ns、THS 0.000 ns，setup/hold failing endpoints 均为 0 | PASS；页面明确显示所有用户时序约束满足 |

`pipeline-project-overview.png` 只作为 Project Summary、`impl_1`、part 和实现完成状态的辅助
上下文，不是第四个报告截图槽位。

## DSP GUI 省略说明

用户确认 Vivado 2023.2 的 Project Summary 和 Report Utilization Summary 都不显示当前
利用量为零的 DSP 行。归档图展示了完整 GUI 表，表从 LUT 到 PLL 结束，并非裁切遗漏。
同一 `impl_1` 的 raw `utilization.rpt` 明确包含：

```text
| DSPs | 0 | 0 | 0 | 90 | 0.00 |
```

同一报告中的 LUT、Slice Registers 和 Block RAM Tile 数值与截图一致，文件 SHA-256 为
`bc5aae538719c11928015f54730fe6c5e095bf40c7fc4d4763ef3675191d4eb8`。因此 DSP=0 使用
“未编辑的官方 GUI 截图 + 同 run raw report”联合证明；不得在截图上人工添加 DSP 行，也
不得仅凭 GUI 缺席推导数值。

## 报告 owner 可引用事实

- 资源：4101 LUT、2241 registers、37.5 BRAM tiles、0 DSP；
- 时序：50 MHz，setup/hold 均满足，WNS 3.912 ns、WHS 0.031 ns、TNS/THS 0；
- 功耗：Vivado routed vectorless estimate 0.189 W，overall confidence Low；
- 以上事实绑定到 manifest 指定的 source、candidate、run、tool、part 和 raw-report hash。

这些是材料事实，不是报告段落或比较结论。队友仍负责报告叙事、排版和最终 PDF，并应按
manifest 核对文件。AR4 完成不表示报告、上传或教师验收已经完成。
