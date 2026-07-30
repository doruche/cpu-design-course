# 课程现场验收准备与官方材料采集任务书

## 状态

- 状态：Active（AR0～AR4 已完成；AR5 Pending，不得自动进入）
- 建立日期：2026-07-30
- 基线提交：`8518ff3c1af0b4836058c5b1d44d061cbbb1aa7f`
- 产品里程碑：`pipeline-soc-stage5`
- 现场最高完成度目标：流水线 SoC 在 EGO1 上运行 CoreMark
- 性质：现场验收能力与官方材料采集；不是产品重构、报告撰写或最终提交封版

本任务接手已经关闭的流水线 SoC 产品，不重新证明 CPU/SoC 是否具备基本功能。目标是
把已有能力整理成可现场演示、可回答设计与代码追问的验收路径，并按当前验收口径采集
可追溯材料，交给报告 owner 使用。

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

固定版本指导书仍提供功能、频率、无时序违例和报告截图要求。用户于 2026-07-30
进一步确认：当前验收只看实验二，现阶段唯一待补材料是流水线 SoC 的三张
Post-Implementation 截图；实验一材料和单周期截图不再需要。现场快照、该确认和指导书
发生冲突或教师给出新口径时，停止当前检查点并更新本任务书，不自行选择更宽松的解释。

### 当前产品证据

- `pipeline-soc-stage5` 已关闭五个 pipeline 配置、225 项 Trace、pipeline C_TEST 0～2、
  CoreMark system、50 MHz clean Vivado implementation、四候选 bitstream 和用户 EGO1
  板测；
- pipeline CoreMark 用户记录为 700 iterations、`14.07890376 s`、`49.7197 CoreMark`、
  `0.9943 CoreMark/MHz`，并有 bitstream/source/COE hash；
- pipeline 四候选实现后 setup/hold 均无违例、未约束路径为零，精选 timing、utilization、
  power 与 provenance 已在 `artifacts/pipeline/`；
- 当前指定的 pipeline CoreMark run 已有 `stage5_evidence.json`、原始
  timing/utilization/power 报告和可打开的 `impl_1`；三张 GUI 截图尚未采集。

## 已确认的范围决定

### 当前只交付实验二流水线截图

用户于 2026-07-30 明确收缩当前验收材料范围：

- 只需要流水线 SoC 的 Post-Implementation Utilization、Power、Timing 三张截图；
- 实验一 ASM/COE、实验一程序构建与双产品证明退出当前任务；
- 单周期截图与单周期材料退出当前任务；
- 已完成的 AR1 现场准备材料保留历史状态，但本轮不再扩写；
- 报告正文/PDF、最终提交目录、ZIP 和上传仍不由本任务拥有。

因此原 AR3“最终实验一程序、双产品候选与自动证明”和 AR-U“用户物理验证与现场演练”
退役，不执行也不作为本任务关闭条件。截图采集仍由用户在 Vivado GUI 中完成，Agent 只
冻结来源并校验截图与 raw evidence 一致。

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

- 流水线 SoC Post-Implementation Timing、Utilization、Power 三张截图；
- 对应的原始文本报告、工具版本、器件、频率、source commit 和候选身份；
- 时序结论、资源表和 routed vectorless 功耗估算的正确解释。

本任务不替队友撰写结论、比较段落、章节正文或生成最终 PDF。报告内容需要额外解释时，
只补充来源明确的事实说明，不扩张为并行报告源。

## 交付目标

本任务关闭时必须同时满足：

1. 流水线 SoC 的实现后 Timing、Utilization、Power 三张官方截图均已采集；
2. 三张截图能绑定到冻结的 source/tool/part/frequency/candidate 和原始报告；
3. Timing 显示正的 setup WNS 与 hold WHS、TNS/THS 为 0 且无 timing violation；
4. Utilization 显示 Slice LUTs、Slice Registers、Block RAM Tiles 和 DSPs 汇总；
5. Power 显示 Total On-Chip Power 与组成，并只表述为 routed vectorless estimate，记录
   Low confidence，不冒充实测；
6. 三张截图和对应 raw evidence 由 manifest 索引，不依赖“最新一次运行”或未命名文件；
7. 报告正文/PDF、最终 ZIP、上传和教师验收明确留给外部 owner，不虚假关闭。

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
- 不采集或补写实验一 ASM/COE、单周期截图或双产品提交材料。

## 责任边界

### Agent 负责

- 维护本任务书、验收矩阵、内部口试准备材料、演示 runbook 和证据 manifest；
- 从 live source 整理模块、握手、状态机和异常路径，给出可回指的提问与核对点；
- 审计 Vivado evidence checker、候选 provenance 与报告 hash；
- 整理流水线 raw/curated Vivado 结果，说明截图应读取的 run 和页面；
- 检查交接材料的来源、版本、命名、一致性和完整性；
- 对失败形成最小复现；需要改变产品合同时停止并重新定界。

### 用户负责

- 在 Vivado GUI 中从指定实现后 run 获取官方要求的 Project Summary 截图；
- 提供教师临时口径、现场问题和队友需要的额外材料项；

### 队友负责

- 提供并维护官方报告模板；
- 使用本任务交接的可追溯材料撰写报告正文、图表、问题说明和结论；
- 生成、复核并拥有最终报告 PDF；
- 对报告需要但材料包未提供的事实提出明确补充请求。

最终提交目录、ZIP 和上传由用户与队友另行确定 owner；在明确前均不属于本任务完成声明。

## 执行规则

1. 严格按 AR0、AR1、AR2、AR4、AR5 顺序执行，前一检查点未关闭不得自动进入下一项；
   AR3 与 AR-U 已按用户范围决定退役。
2. AR0、AR1、AR2 默认是 docs/audit 范围；文档通过不能写成 RTL、Vivado 或板级新证据。
3. 证据合同、截图材料和最终关闭独立提交，不混成一个不可审计提交。
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

状态：Completed（2026-07-30；docs/audit，用户口头复核保留 Pending，不阻塞本检查点）。

默认 write set：

- `docs/acceptance/acceptance-matrix.md`
- `docs/acceptance/demo-runbook.md`
- `docs/acceptance/oral-review.md`
- 本任务书执行记录
- `docs/devlog/README.md`，仅同步 active checkpoint 索引。该最小扩展由用户
  2026-07-30“后续针对性复习，不阻塞当前工程”的决定授权；不改变产品或验收口径，
  仍使用 AR1 文档门禁。

产品源码、脚本、程序、Vivado 工程和 artifacts 只读。

工作：

- 将现场登记项逐项映射到当前 source、自动证据、bitstream 和用户板测记录；
- 冻结 pipeline CoreMark 现场候选、hash、115200/8N1 设置、复位与运行步骤、期望
  transcript、性能值和失败关键词；
- 只基于 live source 整理 CPU/pipeline、Cache、AXI、多周期访存、乘除法、MMIO、UART
  和五外设的模块图、关键事件、常见追问与源码位置；
- 明确哪些结论可由自动证据回答，哪些必须由用户根据理解现场解释；
- 冻结逐题复习台账；实际口头复核由用户后续针对性完成，结果继续标记 Pending，不把
  问题库或背诵文档记为用户理解 PASS。

验证门禁：

```bash
python3 scripts/check_vivado_result.py \
  /mnt/z/cpu-design-vivado/candidates/pipeline/coremark/stage5_evidence.json
just status
just --fmt --check
git diff --check
```

AR1 不复跑产品 closure 或 Vivado，不修改产品行为。

执行记录：

- 新建 `docs/acceptance/acceptance-matrix.md`，将现场登记项映射到 live source、既有自动
  证据、Vivado candidate 和用户板测记录，并区分自动结论与用户解释边界；
- 新建 `docs/acceptance/demo-runbook.md`，冻结 pipeline CoreMark source/COE/manifest/
  selection/bitstream hash、串口设置、reset/运行步骤、期望 transcript 和失败判据；
- 新建 `docs/acceptance/oral-review.md`，从 live source 整理 product owner map、关键事件
  链、常见追问和逐项源码位置，不作为背诵答案或外部数据通路图；
- 只读核对候选目录中的四项 hash 与 `stage5_evidence.json` 一致，并确认从候选 source
  `14a05572ebb585f20a3c83341fb2abe6fb834b0d` 到 AR1 开始时的主线，pipeline RTL、工程、
  程序、脚本、测试、配置和 `Justfile` 无差异；
- 当前未发现候选 provenance 断裂、无法回指 source 的解释、RTL/协议缺陷或教师新增硬件
  形态要求；AR1 停止条件未触发；
- 用户决定先记录完整问题库，此后再针对性复习；`oral-review.md` 已建立 P/S、C、A、M、
  U、E 共 26 项逐题 Pending 台账。该用户-owned 复习不再阻塞 AR1 工程关闭，仍属于
  AR1 的历史未完成项，不能推导为用户理解 PASS；用户后续已把当前材料范围收缩为三张
  实验二截图，因此该复习不再是本任务的关闭条件；
- AR1 到此关闭；没有自动进入 AR2，没有产生新的 RTL、Vivado 或板级证据。

停止条件：

- 现场候选、source commit、bitstream hash 或 transcript 无法一一对应；
- 文档中的解释不能从 live source 或现有 evidence 证明；
- 口试准备暴露真实 RTL/协议缺陷，而不是理解或表达问题；
- 教师要求检查当前任务未覆盖的 IP 拓扑或其他硬件形态。

### AR2：流水线官方截图合同冻结

状态：Completed（2026-07-30；docs/audit，未进入 AR4）。

默认 write set：

- `docs/acceptance/evidence-contract.md`
- 本任务书执行记录

工作：

- 按用户最新口径冻结流水线 Post-Implementation Utilization、Power、Timing 三个截图槽位；
- 冻结文件名、PNG 原始分辨率要求、画面必需字段与拒收条件；
- 冻结 pipeline CoreMark `impl_1` 的 source/tool/part/frequency/candidate、raw report 和
  hash；
- 记录当前 CLI 必须使用显式候选，纠正不可执行的 `just vivado pipeline bitstream`；
- 明确实验一 ASM/COE、单周期截图和双产品证明退出当前任务；
- 不在本检查点生成截图、重跑 Vivado、修改 staging 或进入 AR4。

验证门禁：

```bash
just --fmt --check
git diff --check
git status --short
```

停止条件：

- 三张截图的页面、必需字段或来源 run 仍不明确；
- source/tool/part/frequency/candidate 不能与 raw report 一一对应；
- 现有实现出现 timing violation、报告缺失或 evidence checker 失败；
- 截图要求扩展为实验一、单周期、报告正文或最终提交材料。

执行记录：

- 用户明确当前验收只看实验二，唯一待补材料为流水线 SoC 的 Utilization、Power、Timing
  三张 Post-Implementation 截图；实验一 ASM/COE 与单周期材料退出任务；
- 新建 `docs/acceptance/evidence-contract.md`，冻结三个 PNG 文件名、原始分辨率与可读性
  规则、Vivado 页面、必需字段、预期值和 AR4 拒收条件；
- 来源锁定为 pipeline CoreMark `impl_1`：source
  `14a05572ebb585f20a3c83341fb2abe6fb834b0d`、Vivado 2023.2、
  `xc7a35tcsg324-1`、50 MHz，并记录 bitstream/COE/raw report hash；
- `python3 scripts/check_vivado_result.py` 对
  `/mnt/z/cpu-design-vivado/pipeline/artifacts/stage5_evidence.json` 检查通过；
- live CLI 审计确认 bitstream 必须显式指定 candidate；可复现命令为
  `just vivado-candidate-for pipeline coremark bitstream`，而
  `just vivado pipeline bitstream` 会被 `scripts/vivado.sh` fail closed；
- AR2 仅关闭合同，没有生成 GUI 截图、重跑 Vivado、修改 staging 或自动进入 AR4。

### AR3：最终实验一程序、双产品候选与自动证明

状态：Retired（2026-07-30）。

用户已确认实验一内容不再需要，验收只看实验二。本检查点不执行，原计划中的 ASM/COE、
双产品候选、自动证明和 Vivado/板级工作均不再是当前任务的交付或关闭条件。若将来重新
要求实验一提交材料，应另行建立任务和 owner，不从本检查点自动恢复。

### AR-U：用户物理验证与现场演练

状态：Retired（2026-07-30）。

用户确认当前唯一待补材料为三张实验二流水线截图，因此本检查点不执行，也不作为材料
任务的关闭条件。既有 pipeline CoreMark 用户板测和 AR1 runbook 保留历史证据，不在此
轮重新推导或复跑。

### AR4：官方截图、原始报告与材料 manifest

状态：Completed（2026-07-30；截图与 manifest，不构成报告或教师验收）。

默认 write set：

- `artifacts/acceptance/` 下三张流水线截图与交接 manifest；
- `docs/acceptance/evidence-handoff.md`
- `docs/acceptance/evidence-contract.md`，仅记录用户确认的 Vivado 零 DSP 行 GUI 省略及
  raw-report 补充判据；该最小扩展不改变数值、run 或交付数量；
- 本任务书执行记录

工作：

- 用户从 AR2 指定的 pipeline CoreMark `impl_1` 获取 Utilization、Power、Timing 三张
  Post-Implementation 截图；
- Agent 校验截图与原始 `.rpt`、evidence JSON、source/tool/part/frequency/candidate 一致；
- 生成一份结构化文本 manifest，列出三个 PNG 与对应 raw evidence 的 owner、用途、来源和
  SHA-256；
- 向队友交付事实说明和材料路径，不撰写报告正文。

验证门禁：

```bash
python3 scripts/check_vivado_result.py \
  /mnt/z/cpu-design-vivado/pipeline/artifacts/stage5_evidence.json
git diff --check
git status --short
```

截图无法绑定到指定 run、功耗缺少 confidence、原始报告与摘要不一致或材料 hash 漂移时，
AR4 不得关闭。

执行记录：

- 用户在 Vivado 2023.2 中从 `Z:\\cpu-design-vivado\\pipeline\\miniRV.xpr` 的 routed
  `impl_1` 采集三张 2232×1416 PNG，并额外提供一张 Project Overview 来源辅助图；
- Utilization 图显示 Project Summary 的 Post-Implementation Table：LUT
  4101/20800、FF 2241/41600、BRAM 37.50/50。用户确认 GUI 不显示利用量为零的 DSP 行；
  同 run `utilization.rpt` 明确给出 DSPs 0/90（0.00%），且 LUT/FF/BRAM 数值一致，因此
  采用“官方 GUI 截图 + raw report”联合证明，不修改或伪造截图；
- Power 图显示 Total On-Chip Power 0.189 W、Dynamic 0.115 W、Device Static 0.074 W、
  各部分占比和 confidence `Low`；只作为 routed vectorless estimate；
- Timing 图显示 WNS 3.912 ns、TNS 0.000 ns、WHS 0.031 ns、THS 0.000 ns，setup/hold
  failing endpoints 均为 0，并显示所有用户时序约束满足；
- 三张必交截图归档到 `artifacts/acceptance/screenshots/`；辅助 Overview 同目录保留但在
  manifest 中标记为 non-required；
- `artifacts/acceptance/manifest.tsv` 绑定截图与五个外部 raw evidence 的 SHA-256，
  `docs/acceptance/evidence-handoff.md` 记录交给报告 owner 的事实、限制和路径；
- evidence checker、raw report hash、PNG 格式/尺寸、manifest hash、文档格式和 diff
  门禁均通过；AR4 没有重跑 Vivado、修改 staging、撰写报告或自动进入 AR5。

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

- 复核 AR1、AR2、AR4 的证据、用户确认和材料 manifest；
- 让队友按 manifest 确认材料可读、无缺项，并记录其额外请求或接受结果；
- 更新仓库状态，明确“验收能力/材料已就绪”与“报告/提交/教师验收”之间的边界；
- 确认 canonical product、submodule 和工作树没有生成物污染；
- 仅在用户明确授权后创建材料就绪里程碑 tag。

AR5 不生成报告 PDF、最终 ZIP，不上传作业系统，也不把现场准备写成教师验收 PASS。

## 总体验收

本任务只有在以下条件全部成立后才能关闭：

- 流水线 Utilization、Power、Timing 三张 Post-Implementation 截图满足 AR2 合同；
- 三张截图、原始报告和 provenance 由 manifest 完整索引；
- 队友确认三张图可用于实验二报告；
- 报告正文/PDF、最终 ZIP、上传和教师验收仍按真实状态标记为外部 Pending 或已由对应
  owner 确认，不由本任务推导。

## 停止条件

任一检查点出现以下情况立即停止并请求重新定界：

- 教师新口径要求 Vendor-IP 拓扑、仓库内数据通路图或其他未冻结交付；
- 需要修改 ISA、CPU/pipeline、Cache、AXI、MMIO、UART 或外设合同；
- 当前 source 与已关闭 bitstream/report provenance 不再一致；
- Vivado 出现时序违例、未约束路径、阻塞性 DRC/Critical Warning；
- 截图、raw report、摘要或 hash 相互矛盾；
- 队友要求本任务直接拥有报告正文/PDF，或要求未授权的最终提交封装；
- 需要修改 submodule、Windows staging 或提交被忽略的完整 Vivado run/bitstream。
