# 现场验收矩阵

## 范围与证据等级

本矩阵只服务于现场验收准备。最高完成度登记为 EGO1 上的 pipeline SoC CoreMark；按
当前现场快照，不重复演示被该版本覆盖的中间版本。单周期和 C_TEST 证据仍保留为设计
追问和既有板测记录，不能替代最终实验一程序的后续双产品证明。

证据分为四层：

- **Source**：live canonical source 能说明实现结构与合同；
- **Auto**：仓库自动测试能重复检查的行为；
- **Vivado**：已关闭候选的 implementation、timing、DRC 与 provenance；
- **User**：用户实际完成的 EGO1 观察。只有用户记录可声明板级现象。

AR1 不复跑产品 closure 或 Vivado。下表中的 Auto、Vivado 和 User 结果来自已经关闭的
`pipeline-soc-stage5`；本检查点只校验它们与 live source、候选文件和现场步骤仍能对应。

## 冻结现场候选

| 字段 | 冻结值 |
| --- | --- |
| product / program | `pipeline` / `coremark` |
| bitstream | `/mnt/z/cpu-design-vivado/candidates/pipeline/coremark/miniRV_SoC.bit` |
| source commit | `14a05572ebb585f20a3c83341fb2abe6fb834b0d` |
| bitstream SHA-256 | `36c3f95eaf4faa6b9bd609e783423057af4bee110343f3bce71a2362ec97c6ab` |
| COE SHA-256 | `aaf7c184d27c4c2afeacae8c22f807b75fa1ea584295d16bac344bf37671bae3` |
| manifest SHA-256 | `fbe038c331b6c09c81f646d393b277b61f5f3a7292d309e5b05c7d255818a662` |
| selection SHA-256 | `6a68cb5a2eddae96314ae783055aa838e85eb3c472a8a5978d91fb7ccd7fff69` |
| Vivado / part | 2023.2 / `xc7a35tcsg324-1` |
| clock / UART | 50 MHz / 115200 baud, 8N1, no flow control |

`docs/acceptance/benchmark/candidate-manifest.tsv` 和候选 `stage5_evidence.json` 给出同一组绑定。
AR1 只读审计还确认：从候选 source commit 到 AR1 开始时的 `main`，pipeline RTL、XPR、
XCI/XDC/COE、程序、脚本、测试、配置和 `Justfile` 均无差异。后续若这些 owner 发生变化，
必须重新做 provenance 审计，不能继续使用本结论。

## 登记项矩阵

| 登记项 | Source owner / 关键合同 | Auto evidence | Vivado / bitstream | User evidence | 当前结论 |
| --- | --- | --- | --- | --- | --- |
| 最高版本 | `projects/pipeline/src/rtl/miniRV_SoC.v` 选择 product SoC；`cpu_top.v` 连接 core、Cache 和 AXI master | PC4/PC5 记录：五个 pipeline 配置 lint、225 项 Trace、pipeline C_TEST 0～2、CoreMark system | 上表 CoreMark 候选；evidence checker PASS | PC-U 使用相同 bitstream hash 完成 CoreMark | 现场只演示 pipeline SoC CoreMark |
| 五级 pipeline | `cpu_core.v:32-70` 的 IF/ID、ID/EX、EX/MEM、MEM/WB 状态；`cpu_core.v:79-83` 的停顿优先级 | `just unit pipeline-control`；pipeline 五配置各 45 项 Trace 的关闭记录 | 候选包含同一 pipeline truth | CoreMark 正确完成是端到端观察，不单独证明每一种冒险 | 自动证据回答行为；用户必须解释控制与数据冒险 |
| Cache | `ICache.v:5-7,43-55`；`DCache.v:5-7,54-66`；MMIO 由 `DCache.v:170-171,235-248` 绕过分配 | `just unit cache`、`just integration dcache-mmio`、AXI Trace；CoreMark system 检查 cached refill 与 uncached MMIO | CoreMark 候选由 cache-enabled product build 生成 | CoreMark 板测间接覆盖 Cache；C_TEST 板测补充外设路径 | I/D Cache 均登记为 enabled；结构解释必须回指源码 |
| 乘除法 | `ALU.v:74-78,98-145`；`multiplier.v`；`divider.v`；pipeline 完成控制在 `cpu_core.v:306-344` | `mul/mulh/mulhu/div/divu/rem/remu` Trace；`pipeline-control` 的 mul/div completion overlap | 模块包含在冻结 bitstream 中 | CoreMark 通过不是每条 M 指令的独立板级 oracle | 指令正确性以 Trace 为直接证据；用户解释 `start/busy/capture` |
| AXI 总线控制器 | `axi_master.v:5-8,102-114` 定义仲裁；读/写 FSM 在 `116-230`；AW/W 独立完成在 `198-225` | `just unit axi-master`、AXI Trace、`fabric-mmio`、`dcache-mmio` | 候选实际消费指定 COE；timing/DRC 关闭 | CoreMark UART/timer transcript 是 AXI→MMIO 端到端观察 | 自有状态机 AXI master；不声称使用 AXI Crossbar 等未采用 IP |
| MMIO bridge | `soc_interconnect.v:3-6,106-150`；高 64 KiB 路由至 MMIO；不支持形态返回 DECERR | `just integration fabric-mmio` 与 `dcache-mmio` 覆盖地址、strobe、backpressure 和错误事务 | 冻结候选使用同一 interconnect | CoreMark 访问 UART 和 timer；C_TEST 访问全部五外设 | 自动证据可回答协议结果；用户必须解释地址/握手 owner |
| 拨码开关 | `defines.vh:71`；`miniRV_SoC.v:39-52` 两级同步；`soc_peripherals.v:82-89` 只读 | `just unit peripherals`、`just integration fabric-mmio`、`just system soc-smoke` | 包含在 CoreMark 候选，但 CoreMark 不读取 switch | pipeline C_TEST 0 用户记录验证 switch | 已有板测记录；现场最高版本不重复检查，除非教师要求 |
| LED | `defines.vh:72`；`soc_peripherals.v:59-75,90-95,132`，写入按 byte strobe 合并 | 同上；SoC smoke 检查 switch→LED | 包含在候选，但 CoreMark 不写 LED | pipeline C_TEST 0/1 用户记录验证 LED | 同上 |
| 数码管 | `defines.vh:73`；`soc_peripherals.v:97-103,134-140`；`seven_segment.v:24-56` | `just unit peripherals`、`fabric-mmio`、SoC smoke 检查 8 个 digit slot | 包含在候选，但 CoreMark 不写数码管 | pipeline C_TEST 0/1 用户记录验证数码管 | 同上 |
| UART | `defines.vh:74`；`uart_peripheral.v:3-8,27-50` 定义 16-byte FIFO 与 8N1；寄存器在 `98-116` | UART unit；fabric/MMIO；C_TEST system；CoreMark system 捕获 8N1 transcript | 50 MHz 参数得到 115200 baud；冻结 bitstream 已审计 | CoreMark 与 C_TEST 均有用户 UART transcript 记录 | 现场串口固定为 115200 8N1、无流控 |
| Timer | `defines.vh:75`；`soc_peripherals.v:34,59-65,108-116`；CoreMark `core_portme.c` 以 high-low-high 读取 | timer unit；SoC smoke；CoreMark system 检查 start/stop snapshots | 包含在冻结候选 | CoreMark 的 `Total ticks` 来自该 64-bit free-running timer | 低/高字读取非原子；软件负责 rollover 一致性 |
| 下板频率 | `clock.xdc:1` 约束 100 MHz 输入；`clk_wiz_0.xci` 请求并生成 50 MHz；`miniRV_SoC.v:21-37` 负责 clock/reset | `just unit stage5-contract` 的 clock/reset contract；PC4 closure 记录 | WNS 3.912 ns、TNS 0；WHS 0.031 ns、THS 0；unconstrained paths 0 | 用户在该候选上完成板测 | 登记 50 MHz；不得以 CoreMark 分数反推 timing closure |
| CoreMark 性能 | `programs/c_test/4_coremark/src/coremark/core_portme.c` 固定 `MHZ 50`，timer 计时与最终输出 | `just system coremark` 直接证明 CRC、cached memory、UART MMIO 和 timer snapshots；仿真分数不可上报 | 冻结 700-iteration、13,337-word 候选 | 700 iterations；703,945,188 ticks；14.07890376 s；49.7197 CoreMark；0.9943 CoreMark/MHz；CRC 与结束标记 PASS | 只上报本候选的用户板测值，不上报仿真分数 |
| LLAMA2 | 无 DDR 产品 owner；明确非目标 | Not Run | 无候选 | Not Run | 登记为未实现/未运行，不与 CoreMark 混写 |

## 自动证据与现场回答边界

| 可以直接引用自动证据 | 必须由用户现场解释或观察 |
| --- | --- |
| 某个明确 test/gate 检查了哪些接口与 oracle | 为什么该状态机、优先级或 pending owner 能避免重复请求/错误提交 |
| Trace 对寄存器写回和 store 事件的差分结果 | live source 中一次具体 load、branch、mul/div、MMIO 事务如何流动 |
| evidence JSON 中的 source、COE、bitstream、timing 和 DRC 字段 | 用户是否烧录了该 hash、板上看到什么、串口 transcript 是否完整 |
| CoreMark system 的固定 CRC 与路径覆盖 | 板上十秒规则、实测 ticks/score，以及异常时如何判定失败 |

不得回答成“测试过所以设计一定如此”。遇到无法从 source 或明确 evidence 回指的结论，
记录为待查；如果待查暴露真实 RTL/协议问题，立即触发 AR1 停止条件。

## AR1 停止条件审计

- 候选 source、COE、selection、manifest 和 bitstream hash 已一一对应；
- live product owner 自候选 source 后无变更；
- 本矩阵中的实现说明均能回指 canonical source 或既有 evidence；
- 当前验收口径未要求额外 Vendor-IP 拓扑；
- 尚未发现 RTL/协议缺陷。

以上结论只覆盖 AR1 文档审计，不构成新的 RTL、Vivado 或用户板级 PASS。
