# 单周期 SoC Stage 5：物理工程与自有板级闭环任务书

## 状态

- 状态：Active（S5-0 合同冻结完成；S5-1 尚未开始）
- 父任务：[单周期 SoC 开发](single-cycle-soc.md)
- 基线提交：`6793cf0`
- 产品：`projects/single_cycle/`
- 产品配置：`single-soc-cache`
- 目标板：EGO1（XC7A35TCSG324-1）
- 时钟目标：50 MHz

Stage 5 只负责把已经通过 RTL 自动化的单周期 SoC 变成可复现、可烧录并由用户在
EGO1 上实际验证的物理产品。Stage 4 已证明 C_TEST 0～2 的软件、镜像合同和
CPU-driven 产品拓扑，并使用课程 bitstream 验证了软件交互；本阶段必须改用自己的
canonical RTL、Vivado 工程和 bitstream，不能复用课程 bitstream 结果代替产品证据。

## 本阶段重新划界

本阶段包含：

1. 关闭 canonical 单周期 SoC 的时钟、复位、物理主存容量和程序初始化边界；
2. 建立显式选择 C_TEST 0～2 的 Vivado bitstream 构建路径；
3. 自动运行综合、实现、实现后时序检查和三套候选 bitstream 构建；
4. 由用户在 EGO1 上依次验证自己的三套候选 bitstream；
5. 保存可供后续流水线 SoC 复用的单周期 SoC 物理工程里程碑。

本阶段明确不包含：

- `artifacts/` 下的正式报告归档、截图、资源/功耗对比和最终报告素材；
- 单周期数据通路图、AXI 状态机展示图或其他课程展示图；
- 最终实验报告 PDF、最终提交目录、ZIP 或平铺提交物封版；
- 流水线 CPU、流水线 SoC、CoreMark、LLAMA2、性能优化或两产品 merge；
- 为减少烧录次数而新增 UART 下载器、bootloader 或运行时程序装载协议。

上述展示、报告和最终提交工作统一延期到流水线 SoC 完成并与已验证 SoC fabric merge
之后处理。Stage 5 生成的 Vivado 报告和 bitstream 留在忽略的 staging/build 目录，只在
本文记录关闭所需的摘要、源提交和哈希，不向 `artifacts/` 提交文件。

## 课程与仓库合同

- 单周期 SoC 频率不得低于 25 MHz，下板检查时不得存在时序违例；本仓库当前软硬件
  参数均以 50 MHz 为共同合同，本阶段保持 50 MHz，不静默降频关闭问题。
- C_TEST 0～2 必须在自己的 SoC 上实际运行；课程 bitstream 的 S4-U PASS 只证明软件
  和交互步骤，不证明本产品的 XCI、时钟复位、引脚、实现或 bitstream。
- EGO1 `fpga_clk` 是 P17 上的 100 MHz 输入，`fpga_rst` 是 P15 上的低有效按键；
  UART 使用 115200 baud、8N1、无流控。
- 产品 RTL 只在 `projects/single_cycle/src/rtl/` 修改，板级配置只在 canonical XPR、
  XCI、XDC、COE 选择逻辑和 build Tcl 中维护；Windows staging 仍是一次性派生目录。
- 保持 reset PC `0x00000000`、`miniRV_SoC.U_cpu.U_core` 层次、Trace public 信号和
  Stage 3 已关闭的 Cache/AXI/MMIO 合同。

## 当前进入条件与已知缺口

进入本阶段时，Stage 4 的三个 program build、software suite、CPU-driven System suite
以及课程 bitstream 用户验证均已通过，但以下物理产品缺口仍未关闭：

1. 顶层当前用 `pll_lock & pll_clk1` 组合产生 `sys_clk`，并在 100 MHz `fpga_clk` 域
   生成供 50 MHz 产品域使用的 `sys_rst`。逻辑门控时钟和复位释放跨域必须在
   implementation/bitstream 前修复。
2. `bram_axi.xci` 当前只有 12,800 个 32-bit word（50 KiB），并绑定 `lw.coe`；C_TEST
   linker 的 heap/stack 有效地址上界是 `0x00025800`，物理主存至少需要 153,600 bytes，
   即 38,400 个 32-bit word。
3. 当前公开 Vivado 入口只选择产品和 action，没有显式选择板级程序；不能证明某个
   bitstream 使用了哪份 C_TEST COE。
4. 当前 build Tcl 只检查 Vivado run 是否完成。run 完成、报告生成或 bitstream 写出均
   不自动证明实现后 setup/hold 时序、未约束路径和实现 DRC 已关闭。
5. 自己的单周期 SoC implementation、bitstream 和 EGO1 板测均为 **Not Run**。

## 程序与 bitstream 合同

自己的单周期 SoC 没有课程 bitstream 中的 UART 下载器，程序从 AXI BRAM 初始化内容
直接启动。因此本阶段采用三个独立、显式命名的候选：

| 候选 | 程序输入 | 板级用途 |
| --- | --- | --- |
| `c-test-0` | 同一次构建产生并审计的 `c-test-0.coe` | UART、switch、LED、数码管基础 bring-up |
| `c-test-1` | 同一次构建产生并审计的 `c-test-1.coe` | 格式化 I/O 和交互验证 |
| `c-test-2` | 同一次构建产生并审计的 `c-test-2.coe` | 递归、heap、timer 和排序验证 |

程序选择必须是公开构建入口的显式参数。每个候选构建必须记录：

- clean 源提交、Vivado 2023.2、目标器件和 50 MHz 时钟；
- C_TEST manifest、COE SHA-256 和由 XCI/Tcl 实际消费的初始化文件；
- bitstream SHA-256，以及证明 BRAM 深度不小于 38,400 word 的结构化检查；
- 对应 implementation 的 setup/hold、未约束路径和 DRC 结果摘要。

三套 bitstream 是忽略的构建输出，不提交 Git。不得通过手工修改 Windows staging 中的
XCI/COE 路径生成候选，也不得让一个未命名的“当前 COE”在多次构建间漂移。

## 责任边界

### Agent 默认负责的可重复工程

Agent 默认负责 canonical 工程修改、可重复构建、自动回归和证据判定，包括：

- 建立失败检查并修复时钟、复位和必要的异步输入同步边界；
- 扩展物理 BRAM 容量，建立 C_TEST COE 的显式选择、审计和 staging 传递；
- 修改 canonical RTL、XCI/XPR/XDC、build Tcl、Just CLI、脚本和仓库测试；
- 运行 lint、Unit、Integration、完整 Trace、System 和程序镜像审计；
- 从 WSL 调用 Vivado 2023.2，完成 synthesis、implementation 和 bitstream；
- 自动解析实现后时序、未约束路径、DRC/critical warning，并在不满足合同时令构建失败；
- 计算并记录候选 bitstream、COE 和源提交哈希；
- 为用户准备逐项烧录步骤、串口输入、期望 transcript 和外设观察清单；
- 根据用户反馈定位问题；如需 RTL 修复，先保存最小可重复失败证据，对能够稳定表达的
  行为再补自动回归，然后重新生成候选。

Agent 不把“Vivado batch 成功退出”“生成了 `.bit`”或课程 bitstream PASS 单独写成
Stage 5 完成证据。对于只发生一次、不会成为后续稳定入口的检查，不因 agent 技术上
能够自动化就强制新增长期脚本或门禁。

### 按效率决定的一次性交互任务

对于不接触开发板、但使用 Vivado GUI 或其他交互界面明显比新增自动化更高效的一次性
任务，由 agent 和用户在问题实际出现后选择更合适的执行者。例如：

- implementation 失败后在 Vivado GUI 中 cross-probe 关键路径或查看 schematic；
- batch 报告无法解释时，交互查看 IP 配置、clock interaction 或 DRC 对象；
- Windows/Vivado 环境出现只适合在当前桌面会话处理的临时对话框或工具状态。

此类协助不是 Stage 5 的预设用户义务。Agent 必须先提供明确的目标、只读或写入边界和
结果记录方式；操作结果仍由 agent 结合 canonical 源码和 batch 证据判断。不得为了方便
直接修改 Windows staging，也不得用 GUI 中未保存、不可复现的状态替代 canonical
XPR/XCI/XDC/Tcl 修改。若某项交互后来成为多候选或后续流水线反复依赖的流程，再将其
提升为自动化入口。

### 用户负责的物理操作

以下物理操作必须由用户本人完成：

- 连接 EGO1、USB/JTAG 和 UART，确认实际串口设备；
- 在 Vivado Hardware Manager 中烧录 agent 指定哈希的候选 bitstream；
- 按清单操作低有效复位按键、拨码开关和串口终端；
- 使用 115200 baud、8N1、无流控完成三套 C_TEST 的实际交互；
- 观察并反馈 UART transcript、LED、数码管、switch、timer、排序和 heap 结果；
- 在现象与期望不一致时保留原始输出，说明所用 bitstream 哈希和复现步骤。

用户不负责修改 RTL/XCI、选择 COE、解释 Vivado 时序、手工修补 staging 或判断自动
回归范围。用户可以按上一节约定协助一次性交互排障，但 agent 必须先把候选和物理操作
清单准备到可直接执行的状态，再请求用户板测。

## 验证分层

| 层级 | 执行者 | 证明 | 不证明 |
| --- | --- | --- | --- |
| RTL/Program | Agent | 逻辑、软件和镜像合同保持成立 | XCI、时钟、引脚和物理 I/O |
| Vivado synthesis | Agent | canonical 工程可综合、资源规模可实现 | 布局布线后时序和实板行为 |
| Vivado implementation | Agent | 50 MHz 实现后 setup/hold、约束和 DRC 合同 | 板线、UART 终端和人工交互 |
| Bitstream provenance | Agent | `.bit` 与源提交、程序 COE、器件和实现一一对应 | bitstream 已在 EGO1 运行 |
| EGO1 board | 用户 | 自己的物理产品和五类外设实际成立 | 后续流水线 merge 或最终课程交付 |

表中的执行者表示该层证据的默认所有者，不排除用户按上一节约定协助一次性 GUI 操作；
协助操作不会转移证据判定和 canonical 工程维护责任。

## 实施检查点

### S5-0：合同冻结

状态：Completed（2026-07-27，docs-only）。

- 冻结本阶段范围、三候选策略、agent/user 责任、验证分层和停止条件；
- 记录时钟复位、BRAM 容量、隐式 COE 和 Vivado 判定缺口；
- 明确 `artifacts/`、数据通路图、报告和最终提交延期到流水线 merge 后；
- 不修改 RTL、Vivado 工程、构建脚本或生成 bitstream。

### S5-1：失败基线与物理合同检查

- 只为会被多个候选或后续流水线重复消费、且能够稳定表达行为合同的边界建立自动
  检查：至少覆盖 reset/PLL lock 行为、BRAM 最小容量和候选 COE 选择；
- 自动检查应在当前基线上复现能够稳定表达的 50 KiB、`lw.coe` 隐式绑定和复位行为
  缺口；逻辑门控时钟、CDC 结构等一次性设计缺陷可由代码审查和 Vivado 检查形成基线，
  不要求为源码写法建立脆弱的文本模式测试；
- 冻结 50 MHz 下 UART、timer 和 C_TEST 时钟参数一致性；
- 明确 implementation 对 setup、hold、未约束路径和 DRC 的机器判定条件。

默认写集：`tests/`、`scripts/`、`Justfile`、必要的配置清单和本文。此检查点不修改
产品 RTL/XCI；自动失败用例和一次性审查的对应基线均成立后才进入 S5-2。

### S5-2：板级工程修复与候选构建入口

- 使用未门控的 Clock Wizard 输出驱动产品时钟；复位必须在产品时钟域安全释放，并在
  PLL 未锁定或板级复位有效时保持产品复位；
- 审计 switch 和 UART RX 等异步输入，已有同步器必须保留，缺失且影响物理正确性的
  边界在本检查点补齐；
- 将 AXI BRAM 有效容量扩展到至少 153,600 bytes，并保持 C_TEST 运行区间可写；
- 让公开入口显式选择 `c-test-0|c-test-1|c-test-2`，把同次审计的 COE 传给 canonical
  Vivado build；禁止依赖 `lw.coe` 或 staging 手工操作；
- 强化 build Tcl/后处理，使实现时序、未约束路径或 DRC 不满足时构建失败。

默认写集：`projects/single_cycle/src/rtl/miniRV_SoC.v`、必要的新板级小模块、
`projects/single_cycle/miniRV.xpr`、`src/rtl/ip/bram_axi/bram_axi.xci`、必要的 XDC、
`projects/single_cycle/scripts/build.tcl`、`scripts/`、`Justfile` 和 S5-1 测试。

若需要改变 CPU ISA、Trace public 信号、Stage 3 Cache/AXI/MMIO 语义、C_TEST 软件功能
或引入 bootloader，立即停止并重新定界。

### S5-3：自动回归、实现和三套 bitstream

- 先运行受影响的 targeted test，再运行 `just gate single-stage4-auto`；
- 对 clean 源提交运行 canonical Vivado synthesis 和 implementation；
- 在 50 MHz 下检查 setup/hold、未约束路径、DRC 和 critical warning；
- 分别构建 C_TEST 0～2 三套 bitstream，验证 XCI 实际消费的 COE 与 manifest/hash；
- 生成面向 S5-U 的候选清单：源提交、bitstream hash、程序 hash、串口设置和步骤。

Vivado 完整日志、报告和 bitstream 继续留在忽略的 staging/build 目录。本检查点只在
任务书中记录必要摘要，不创建 `artifacts/` 里程碑目录。若 implementation 不能在
50 MHz 收敛，先定位时序路径；不得直接降频或修改 C_TEST 时钟常量掩盖问题。

### S5-U：自己的 EGO1 用户板测

本检查点由 agent 准备、用户执行：

1. 先烧录 `c-test-0`，验证复位可重复、UART、switch、LED 和八位数码管；
2. 再烧录 `c-test-1`，验证格式化输出、输入回显、符号 LED 和绝对值数码管；
3. 最后烧录 `c-test-2`，验证两轮排序、动态内存和 timer 关系；
4. 每次记录 bitstream SHA-256、实际 transcript、外设现象和 PASS/FAIL；
5. 任一失败都回到最小可复现和对应自动层，不用其他候选的 PASS 替代。

只有三套自己的 bitstream 均通过，S5-U 才能关闭。课程 bitstream 的既有结果保留为
软件 oracle，但不计入本检查点 PASS。

### S5-4：单周期 SoC 关闭与交接

- 在最终 RTL/工程提交上重跑 Stage 5 自动门禁和必要的 clean Vivado 候选构建；
- 记录 S5-U 三套用户结果，更新 README、父任务和开发日志索引；
- 确认两个 submodule 未修改，canonical 工程无生成物污染，工作树干净；
- 保存单周期 SoC 物理产品里程碑 tag，作为后续流水线 SoC merge 的 fabric 基线。

本检查点不创建正式 `artifacts/` 报告，不修改数据通路图，也不生成最终提交 ZIP。

## 自动关闭门禁

进入 S5-U 前至少要求：

- S5-1 中适合自动化的失败用例已在修复前复现、修复后通过；一次性代码/CDC 审查项
  已保存修复前结论并由修复后的 Vivado 证据关闭；
- `just gate single-stage4-auto` 通过，六配置 lint/Trace、Stage 3 集成和三个 C_TEST
  System suite 保持通过；
- canonical XPR/XCI/XDC/COE 选择可结构化审计，BRAM 不小于 153,600 bytes；
- clean 源提交的 Vivado 2023.2 synthesis 和 implementation 完成；
- 50 MHz 实现后 setup/hold 无违例、无未约束路径，阻塞性 DRC/critical warning 为零；
- 三套 bitstream 均与各自 C_TEST manifest/COE 一一对应并有 SHA-256；
- 两个 submodule 固定且未修改；
- `artifacts/`、数据通路图、最终报告和最终提交明确报告为 Deferred，而非 Completed。

Stage 5 完整关闭还要求 S5-U 的 C_TEST 0、1、2 均由用户在自己的 EGO1 bitstream 上
记录为 PASS。

## 停止条件

出现以下任一情况立即停止当前检查点并请求重新定界：

- 需要修改指导书、Trace submodule、课程 bitstream 或 Windows staging 中的派生文件；
- 需要改变 CPU ISA、设计 CSV、Trace public 信号、层次或 reset PC；
- 需要改变 Stage 3 已关闭的 Cache、AXI、MMIO 地址或 UART 寄存器语义；
- 需要修改 C_TEST 功能来适配硬件，而不是修复硬件/构建边界；
- 需要新增 bootloader、UART 下载协议、DDR、CoreMark 或 LLAMA2；
- 需要进入流水线产品、两产品 merge、正式 `artifacts/`、数据通路图或最终报告；
- 50 MHz implementation 不能收敛，或存在无法解释的未约束路径/阻塞性 DRC；
- 用户报告的板级失败无法绑定到确定的 bitstream hash、程序和复现步骤。

## 完成后的交接

Stage 5 完成后，单周期产品交付的是经过自动回归、Vivado implementation、三套可追溯
bitstream 构建和用户 EGO1 验证的 SoC fabric 基线。后续流水线 SoC 应复用该物理边界，
但必须重新验证流水线核心接入后的 AXI、时序和板级行为。

待流水线 SoC 完成并 merge 后，再统一整理单周期/流水线的 `artifacts/`、数据通路图、
资源/功耗/时序对比、最终报告和提交包；这些后续工作不得倒推为 Stage 5 未完成，也
不得用 Stage 5 的单周期证据替代流水线产品证据。
