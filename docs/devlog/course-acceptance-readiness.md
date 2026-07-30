# 课程现场验收准备与官方材料采集任务书

## 状态

- 状态：Active（AR0 已完成；AR1 Pending，不得自动进入）
- 建立日期：2026-07-30
- 基线提交：`8518ff3c1af0b4836058c5b1d44d061cbbb1aa7f`
- 产品里程碑：`single-cycle-soc-stage5`、`pipeline-soc-stage5`
- 现场最高完成度目标：流水线 SoC 在 EGO1 上运行 CoreMark
- 性质：现场验收能力与官方材料采集；不是产品重构、报告撰写或最终提交封版

本任务接手已经关闭的单周期和流水线 SoC 产品，不重新证明 CPU/SoC 是否具备基本
功能。目标是把已有能力整理成可现场演示、可回答设计与代码追问的验收路径，并按官方
流程采集可追溯材料，交给报告 owner 使用。

本任务的交付不是实验报告正文、最终 PDF 或提交 ZIP。材料交接完成也不能写成报告已经
完成、作业已经提交或教师已经验收。

## 输入与验收口径

### 现场验收快照

用户提供的本地验收快照为 `materials/lab2/acceptance-check.png`：

- SHA-256：`1c58fcd274c1ae29b1ab128fac5e3daadebff03ddd49eb10c80ee000b3d18158`
- 图片尺寸：1510 x 1210；
- 该文件位于 Git 忽略的 `materials/lab2/`，不能假设其他 checkout 自动拥有它；
- 本任务记录其影响验收边界的结论，不复制课件全文，也不把图片提交到 Git。

快照给出的当前现场口径是：

- 系统实现按完成度分档；流水线 SoC 下板运行 CoreMark 属于最高基础档目标；
- 只检查完成度最高的版本，不重复检查已经被最高版本覆盖的中间版本；
- 功能正确后会随机追问设计和代码，只有一次回答机会；
- 回答质量按理解程度分档，不能把未理解的生成内容当作验收准备；
- 登记项包含 Cache、乘除法、外设、下板频率和 CoreMark/LLAMA2 性能；
- 当前快照没有把 AXI Crossbar、AXI GPIO、Protocol Converter 或 AXI Uartlite 列为
  独立检查项。

固定版本指导书仍提供功能、频率、无时序违例、报告截图和提交目录要求。现场快照和
指导书发生冲突或教师给出新口径时，停止当前检查点并更新本任务书，不自行选择更宽松的
解释。

### 当前产品证据

- `pipeline-soc-stage5` 已关闭五个 pipeline 配置、225 项 Trace、pipeline C_TEST 0～2、
  CoreMark system、50 MHz clean Vivado implementation、四候选 bitstream 和用户 EGO1
  板测；
- pipeline CoreMark 用户记录为 700 iterations、`14.07890376 s`、`49.7197 CoreMark`、
  `0.9943 CoreMark/MHz`，并有 bitstream/source/COE hash；
- pipeline 四候选实现后 setup/hold 均无违例、未约束路径为零，精选 timing、utilization、
  power 与 provenance 已在 `artifacts/pipeline/`；
- 单周期产品已有 50 MHz clean implementation、三候选 bitstream 和用户 C_TEST 0～2
  板测；原始 timing、utilization、power 和 evidence 仍在 Windows staging，但尚未整理为
  与 pipeline 对称的正式材料；
- `scripts/export-submission.sh` 能平铺两套产品 RTL 并运行两套完整 Trace，但最终报告、
  实验一 ASM/COE 和身份输入尚未冻结，因此不能把该入口写成最终提交已完成。

## 已确认的范围决定

### 保留当前物理拓扑

当前产品使用 Clock Wizard 与 AXI BRAM Vendor IP，自有 `soc_interconnect`、外设 fabric
和 UART RTL。现场验收快照没有把具体 Vendor-IP 拓扑列为检查项，现有实现又已经通过
功能、Vivado 和板级证据，因此本任务不迁移 AXI Crossbar、AXI GPIO、Protocol Converter
或 AXI Uartlite。

若教师明确要求特定 IP，属于物理拓扑、XPR/XCI、仿真模型、资源时序和既有 evidence 的
整体扩展，必须另开产品变更任务，不能夹带在验收材料采集中。

### 数据通路图由外部 owner 负责

用户确认数据通路图已经在其他位置完成。本任务：

- 不读取、修改、导出或复核该图；
- 不修改 `design/single_cycle/complete_datapath.drawio` 或设计 CSV；
- 不把仓库内图的状态写成现场图已经验收；
- 现场材料清单只保留一个外部 owner 交付槽位，不复制第二份真相。

### 报告由队友负责

队友拥有报告模板、正文、图表叙事、排版和最终 PDF。本任务只交付可核验输入：

- 单周期与流水线 Post-Implementation Timing、Utilization、Power 截图；
- 对应的原始文本报告、工具版本、器件、频率、source commit 和候选身份；
- 时序/DRC 结论、资源表和功耗估算的正确解释；
- C_TEST/CoreMark 板级 transcript、性能值、bitstream/COE/source hash；
- 最终实验一 ASM/COE 和两产品可运行证据；
- 现场发现问题及其修复记录，供队友按验收要求写入报告。

本任务不替队友撰写结论、比较段落、章节正文或生成最终 PDF。报告内容需要额外解释时，
只补充来源明确的事实说明，不扩张为并行报告源。

## 交付目标

本任务关闭时必须同时满足：

1. 现场最高完成度明确登记为 pipeline SoC CoreMark，候选 bitstream、串口参数、操作步骤、
   期望输出和失败判据均可在现场直接使用；
2. 用户能够依据 live source 解释 CPU、pipeline、Cache、AXI、多周期完成、MMIO、UART 和
   外设关键路径；内部准备材料不得包含无法回指源码的模板答案；
3. 单周期与流水线的实现后 Timing、Utilization、Power 官方截图和原始报告均已采集，且
   能绑定到 source/tool/part/frequency/candidate；
4. 功耗只表述为 Vivado routed vectorless estimate，并记录 Low confidence，不冒充实测；
5. 最终实验一 ASM/COE 有唯一 owner、确定版本、hash 和可见结果判据，同一材料可交给
   single_cycle 与 pipeline 提交目录；
6. 两套产品使用最终实验一程序的自动检查、bitstream provenance 和用户板级观察均已
   记录，不用 C_TEST/CoreMark 结果替代该程序的可运行性；
7. 所有交给队友的截图、文本报告、transcript、hash 和程序材料由一份 manifest 索引，
   不依赖“最新一次运行”或未命名文件；
8. 数据通路图、报告正文/PDF、最终 ZIP 和作业系统上传明确留给各自 owner，不虚假关闭。

## 必须保持的不变量

- 保持两个 product truth、十个稳定配置、`miniRV_SoC.U_cpu.U_core` 层次、Trace public
  信号和 reset PC；
- 保持 CPU、Cache、AXI、MMIO 地址、UART 寄存器和五外设行为；
- 保持 EGO1 100 MHz 输入、50 MHz 产品时钟、115200 baud、8N1、无流控；
- 不修改 `cdp-tests/` 或 `materials/instruction-site/` submodule；
- 不编辑 Windows staging；截图或报告发现问题时回到 canonical owner；
- 不用截图、报告文本或口试材料替代可执行验证；
- 不把旧 candidate 的 report、bitstream 或 transcript 绑定到新 source/program；
- 不因材料整理而重写已经关闭的产品历史或移动里程碑 tag。

## 明确非目标

- 不处理数据通路图及其现场展示；
- 不迁移或新增 Vendor IP；
- 不重构 CPU、pipeline、Cache、AXI、interconnect、UART 或外设；
- 不优化频率、CoreMark、Cache 参数、乘除法器或资源占用；
- 不实现 DDR、LLAMA2、额外外设或加分项；
- 不撰写实验报告，不生成最终报告 PDF；
- 不决定队友的报告结构、措辞或视觉排版；
- 不自动生成最终提交 ZIP，不上传作业系统；
- 不替用户完成板级操作、现场口试、出勤或教师确认。

## 责任边界

### Agent 负责

- 维护本任务书、验收矩阵、内部口试准备材料、演示 runbook 和证据 manifest；
- 从 live source 整理模块、握手、状态机和异常路径，给出可回指的提问与核对点；
- 审计和运行自动化门禁、Vivado evidence checker、program/candidate 构建与 hash；
- 为最终实验一 ASM/COE 建立确定的构建、选择和双产品验证路径；
- 整理单周期与流水线 raw/curated Vivado 结果，说明截图应读取的 run 和页面；
- 检查交接材料的来源、版本、命名、一致性和完整性；
- 对失败形成最小复现；需要改变产品合同时停止并重新定界。

### 用户负责

- 在 Vivado GUI 中从指定实现后 run 获取官方要求的 Project Summary 截图；
- 连接 EGO1、JTAG、UART，烧录指定 hash 的 bitstream 并记录实际观察；
- 亲自理解并回答设计/代码问题，完成现场演示和出勤；
- 提供教师临时口径、现场问题和队友需要的额外材料项；
- 确认最终实验一程序的展示现象满足课程意图。

### 队友负责

- 提供并维护官方报告模板；
- 使用本任务交接的可追溯材料撰写报告正文、图表、问题说明和结论；
- 生成、复核并拥有最终报告 PDF；
- 对报告需要但材料包未提供的事实提出明确补充请求。

最终提交目录、ZIP 和上传由用户与队友另行确定 owner；在明确前均不属于本任务完成声明。

## 执行规则

1. 严格按 AR0、AR1、AR2、AR3、AR-U、AR4、AR5 顺序执行，前一检查点未关闭不得自动
   进入下一项。
2. AR0、AR1、AR2 默认是 docs/audit 范围；文档通过不能写成 RTL、Vivado 或板级新证据。
3. 每个实现或证据检查点独立提交；程序、构建入口、Vivado 候选、截图材料和最终关闭不
   混成一个不可审计提交。
4. 需要扩展 write set 时先记录 owner、原因、验收影响和新增门禁，获得用户确认后继续。
5. 任何现有候选或自动检查失败都先保存原始证据；不通过放宽判定、改报告措辞或换候选
   掩盖问题。
6. 用户板测与口试理解不能由 agent 推导为 PASS，必须由用户明确确认。

## 实施检查点

### AR0：任务书与责任边界冻结

状态：Completed（2026-07-30；docs-only，未进入 AR1）。

默认 write set：

- `docs/devlog/course-acceptance-readiness.md`
- `docs/devlog/README.md`
- `README.md`
- `docs/workflow.md`

工作：

- 记录现场验收快照的 hash、完成度分档、最高版本检查和随机追问边界；
- 将 Vendor-IP 迁移从当前验收待办中移除，同时保留教师新口径的停止条件；
- 冻结 Agent、用户、队友三方责任；
- 明确数据通路图、报告正文/PDF 和最终 ZIP 不在本任务内；
- 定义后续检查点、默认 write set、门禁和停止条件；
- 不修改 RTL、程序、脚本、Vivado 工程、报告或生成物。

验证门禁：

```bash
just --fmt --check
just doctor
git diff --check
git status --short
```

AR0 只证明任务书与索引一致，不构成现场口试、Vivado 截图、最终程序或板级证据。

### AR1：验收矩阵、演示 runbook 与源码口试准备

状态：Pending。

默认 write set：

- `docs/acceptance/acceptance-matrix.md`
- `docs/acceptance/demo-runbook.md`
- `docs/acceptance/oral-review.md`
- 本任务书执行记录

产品源码、脚本、程序、Vivado 工程和 artifacts 只读。

工作：

- 将现场登记项逐项映射到当前 source、自动证据、bitstream 和用户板测记录；
- 冻结 pipeline CoreMark 现场候选、hash、115200/8N1 设置、复位与运行步骤、期望
  transcript、性能值和失败关键词；
- 只基于 live source 整理 CPU/pipeline、Cache、AXI、多周期访存、乘除法、MMIO、UART
  和五外设的模块图、关键事件、常见追问与源码位置；
- 明确哪些结论可由自动证据回答，哪些必须由用户根据理解现场解释；
- 由用户完成至少一轮随机顺序口头复核；未理解项回到源码，不把背诵文档记为通过。

验证门禁：

```bash
python3 scripts/check_vivado_result.py \
  /mnt/z/cpu-design-vivado/candidates/pipeline/coremark/stage5_evidence.json
just status
just --fmt --check
git diff --check
```

AR1 不复跑产品 closure 或 Vivado，不修改产品行为。

停止条件：

- 现场候选、source commit、bitstream hash 或 transcript 无法一一对应；
- 文档中的解释不能从 live source 或现有 evidence 证明；
- 口试准备暴露真实 RTL/协议缺陷，而不是理解或表达问题；
- 教师要求检查当前任务未覆盖的 IP 拓扑或其他硬件形态。

### AR2：官方材料合同与最终实验一程序冻结

状态：Pending。

默认 write set：

- `docs/acceptance/evidence-contract.md`
- `docs/acceptance/final-program-contract.md`
- 本任务书执行记录

工作：

- 与队友确认报告实际需要的截图槽位、命名、分辨率和附带数据，不代写报告；
- 冻结单周期/流水线 Post-Implementation Timing、Utilization、Power 的来源 run 和
  source/tool/part/frequency/candidate 元数据；
- 冻结 transcript、性能、候选 hash、问题修复记录和外部数据通路图的交接槽位；
- 从现有实验一汇编候选中选择或定义唯一最终程序，明确可见结果、结束判据、内存边界、
  同一 ASM/COE 双产品使用和 hash 合同；
- 冻结 AR3 所需的最小程序/build/candidate write set，不在本检查点实现。

验证门禁：

```bash
just --fmt --check
git diff --check
git status --short
```

停止条件：

- 队友需要的报告模板或截图规格尚不明确；
- 最终实验一程序选择需要改变 ISA、CPU/SoC 行为或官方提交目录语义；
- 现有程序没有可重复的汇编到 COE 路径或可见验收判据；
- 两产品不能合法共享同一 ASM/COE。

### AR3：最终实验一程序、双产品候选与自动证明

状态：Pending；具体 write set 必须由 AR2 冻结后填写，不得提前实现。

预期 owner 仅包括：

- `programs/` 下最终实验一程序及其最小构建入口；
- `scripts/`、`Justfile` 和 repository-owned tests 中显式程序/candidate 路由；
- 两产品 candidate selection 所需的 canonical 配置；
- 本任务书执行记录。

工作：

- 从唯一 ASM 源可重复生成 COE、manifest 和 hash；
- 对 single_cycle 与 pipeline 显式构建同一最终程序候选，不依赖手工替换 XCI/COE；
- 建立程序可见结果的自动 oracle，并验证内存范围、reset PC 和结束路径；
- 运行两产品相关 lint/Trace/System 和 exported-source preflight；
- 为两产品生成 clean Vivado 2023.2 implementation/bitstream evidence，检查 50 MHz、
  setup/hold、未约束路径、DRC 和 candidate provenance；
- 不修改 CPU、Cache、AXI、MMIO 或外设来适配程序。

最低门禁由 AR2 结合程序形态冻结，至少包含：

```bash
just unit stage5-contract
just trace-all single-basic
just trace-all pipeline-basic
just lint single-soc-cache
just lint pipeline-soc-cache
git diff --check
```

Vivado 和板级命令必须在 AR2 冻结的 candidate 名称下显式执行，不能使用未命名“当前
COE”。

### AR-U：用户物理验证与现场演练

状态：Pending；只在 AR3 自动和 Vivado 证据关闭后进入。

默认 write set：

- `docs/acceptance/board-evidence.md`
- `docs/acceptance/rehearsal-record.md`
- 本任务书执行记录

工作：

- 用户分别在 single_cycle 与 pipeline 上烧录 AR3 指定 hash 的最终实验一 bitstream，
  记录可见结果；
- 用户使用既有 pipeline CoreMark 候选完成一次现场顺序演练，确认 bitstream 可取得、串口
  设置、复位、运行时间和 transcript 判据；
- 按随机顺序完成一次源码口试演练，记录仍需回读源码的问题；
- 核对现场设备、JTAG、UART 端口、开发板借还和出勤安排；
- 只记录用户实际观察，不把 agent 的预期输出写成用户 PASS。

AR-U 不修改 RTL、程序、Vivado 工程或候选；任何失败回到拥有该行为的前置检查点。

### AR4：官方截图、原始报告与材料 manifest

状态：Pending。

默认 write set：

- `artifacts/single_cycle/` 下精选实现后文本证据；
- `artifacts/acceptance/` 下截图、transcript、程序与交接 manifest；
- `artifacts/pipeline/`，仅补充 AR3 最终程序或交接索引；
- `docs/acceptance/evidence-handoff.md`
- 本任务书执行记录

工作：

- 用户从 AR3 指定的两产品 post-implementation run 获取官方 Project Summary 的 Timing、
  Utilization、Power 截图；
- Agent 校验截图与原始 `.rpt`、evidence JSON、source/tool/part/frequency/candidate 一致；
- 为单周期补齐与 pipeline 对称的 timing/utilization/power/provenance 精选摘要；
- 收集最终程序 ASM/COE、hash、双产品 bitstream 证据、板级观察、pipeline CoreMark
  transcript/性能和现场问题记录；
- 生成一份机器可读或结构化文本 manifest，列出每个材料的 owner、用途、来源和 SHA-256；
- 向队友交付事实说明和材料路径，不撰写报告正文。

验证门禁：

```bash
python3 scripts/check_vivado_result.py <single-final-evidence.json>
python3 scripts/check_vivado_result.py <pipeline-final-evidence.json>
git diff --check
git status --short
```

截图无法绑定到指定 run、功耗缺少 confidence、原始报告与摘要不一致或材料 hash 漂移时，
AR4 不得关闭。

### AR5：材料交接关闭

状态：Pending。

默认 write set：

- `README.md`
- `AGENTS.md`
- `docs/workflow.md`
- `docs/devlog/README.md`
- `artifacts/README.md`
- `docs/acceptance/`
- 本任务书

工作：

- 复核 AR1～AR4 与 AR-U 的证据、用户确认和材料 manifest；
- 让队友按 manifest 确认材料可读、无缺项，并记录其额外请求或接受结果；
- 更新仓库状态，明确“验收能力/材料已就绪”与“报告/提交/教师验收”之间的边界；
- 确认 canonical product、submodule 和工作树没有生成物污染；
- 仅在用户明确授权后创建材料就绪里程碑 tag。

AR5 不生成报告 PDF、最终 ZIP，不上传作业系统，也不把现场准备写成教师验收 PASS。

## 总体验收

本任务只有在以下条件全部成立后才能关闭：

- pipeline CoreMark 现场 runbook、候选和用户演练成立；
- 用户完成源码理解复核，不存在已知无法解释的关键产品路径；
- 最终实验一 ASM/COE 在两产品自动、Vivado 和用户板级边界成立；
- 两产品官方截图、原始报告、性能/transcript 和 provenance 由 manifest 完整索引；
- 队友确认材料可用于报告，数据通路图继续由外部 owner 提供；
- 报告正文/PDF、最终 ZIP、上传和教师验收仍按真实状态标记为外部 Pending 或已由对应
  owner 确认，不由本任务推导。

## 停止条件

任一检查点出现以下情况立即停止并请求重新定界：

- 教师新口径要求 Vendor-IP 拓扑、仓库内数据通路图或其他未冻结交付；
- 需要修改 ISA、CPU/pipeline、Cache、AXI、MMIO、UART 或外设合同；
- 当前 source 与已关闭 bitstream/report provenance 不再一致；
- 最终实验一程序不能在两产品共享，或没有确定的构建/结束/可见结果判据；
- Vivado 出现时序违例、未约束路径、阻塞性 DRC/Critical Warning；
- 板级观察、截图、raw report、摘要或 hash 相互矛盾；
- 队友要求本任务直接拥有报告正文/PDF，或要求未授权的最终提交封装；
- 需要修改 submodule、Windows staging 或提交被忽略的完整 Vivado run/bitstream。
