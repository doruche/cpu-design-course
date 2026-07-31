# 构建系统、CLI 与完整 SoC 验证间章任务书

## 状态

- 状态：Completed（2026-07-26）
- 建立日期：2026-07-26
- 基线提交：`6bad8c6`
- 位置：单周期 SoC Stage 3 与 Stage 4 之间
- 首要产品：`projects/single_cycle/`
- 兼容产品：`projects/pipeline/`
- 当前本机 Just：`1.57.0`

本间章暂停单周期 SoC 的课程阶段推进，先整理仓库构建系统、命令行接口和自动化验证
边界。完成前不进入 C_TEST、bitstream 或实际下板；完成后 Stage 4 才使用新的统一入口
继续推进。

课程行为仍以固定版本的指导书和 Trace 框架为准。本任务不修改两个 submodule，也不把
课程指导书的内容复制为本地规范。

## 为什么需要这个间章

迁移基线中的根 `Makefile` 能够运行 Stage 0～3 所需门禁，但接口逐步叠加了四类不同概念：

- 产品选择：`single_cycle` / `pipeline`；
- 运行拓扑：历史 Basic 主存、AXI 直连行为级 BRAM、非 Trace 板级 SoC；
- Cache 配置：旁路或同时启用 ICache/DCache；
- 验证层级：lint、模块测试、局部集成、Trace、Vivado 和阶段汇总门禁。

这些概念目前通过 `PRODUCT`、`TRACE_PROFILE`、`CACHE`、`RUN_TRACE`、
`BASIC_TRACE` 和层层递归的 Make target 共同决定。一个命令名往往不能直接说明实际
编译了什么拓扑，也不能直接说明 PASS 的证明边界。例如：

- `soc-stage3-test` 同时包含 Stage 3 测试、完整 Stage 2 门禁和三轮 Trace；
- `soc-stage3-full-test` 实际从 DCache 的 CPU 侧接口开始，不包含 CPU 和 ICache；
- 当前 AXI Trace 在 `RUN_TRACE` 分支中让 CPU/Cache/AXI master 直连行为级 BRAM，
  绕过 `soc_interconnect` 和全部 MMIO 外设；
- `tests/cdp/obj_dir` 被所有 Trace 配置共享，配置切换依赖仓库侧 stamp 清理；
- 根 `make check` 的实际产品、主存和 Cache 配置依赖默认变量，命令名本身不可审计；
- `make help` 的文本提取方式不能正确展示跨行声明的 `soc-stage3-test`。

继续在这些入口上添加 Stage 4 或流水线 SoC 命令，会扩大隐藏配置和名字过载。因此本
间章先关闭构建接口和验证拓扑，再开始新的课程功能阶段。

## 目标

1. 以根 `Justfile` 作为仓库唯一公开构建与验证 CLI，使用 `just` 取代根 `make`。
2. 把产品配置、仿真拓扑、Cache 模式、执行后端和测试层级变成可列举、可检查的显式
   合同，拒绝无效组合。
3. 让命令在执行前打印解析后的配置、输入和输出目录，使一条验证记录能够说明它实际
   证明了什么。
4. 分开模块测试、局部集成、Trace、程序级 SoC 仿真和 FPGA/实板验证，不再用一个
   `full` 名称覆盖不同层级。
5. 增加包含 CPU、双 Cache、AXI master、系统互连和行为级主存的 product-topology
   AXI Trace。
6. 增加由 CPU 执行测试程序、覆盖主存和五类 MMIO 的 Cache-enabled SoC 系统仿真。
7. 保留历史 Basic Trace、AXI 直连诊断能力、Vivado staging 和提交导出能力，并保证
   `projects/pipeline/` 的既有 Basic Trace 不回退。

## 非目标

- 不开始或补写 C_TEST 0～2，不切换正式 COE 程序镜像；
- 不运行 Vivado implementation、生成 bitstream 或声明实际板级结果；
- 不处理既有时钟门控和跨时钟域复位风险；它们仍在 implementation 前单独关闭；
- 不修改 CPU ISA 行为、两份设计 CSV、Cache/MMIO 对外语义或 Trace public 信号；
- 不修改 `tests/cdp/`、`docs/instruction-site/` 或 `tests/cdp/mySoC/`；
- 不以机械包装 `make <target>` 作为最终 Just 架构；
- 不为了统一 CLI 把 Vivado、Icarus Verilog、Verilator 和 Trace 强行合并成同一种执行
  后端。

## 所有权与真相源

| 关注点 | 所有者 | 约束 |
| --- | --- | --- |
| 公开 CLI、配置名和门禁编排 | 根 `Justfile` | 不在多个入口重复维护同一决策 |
| 非平凡循环、环境检查和工具适配 | `scripts/` | Just recipe 保持短小，脚本可独立诊断 |
| 产品 RTL | `projects/<product>/src/rtl/` | 仿真不得复制产品模块形成第二份实现 |
| 仿真 testbench 和程序 | `tests/` | 生成物进入忽略的 `.cache/` |
| Trace golden behavior | `tests/cdp/` submodule | 只消费固定版本，不在本任务中修改 |
| Vivado 工程/IP/约束 | canonical product 工程 | Windows staging 仍是派生目录 |
| 历史执行证据 | 已有开发日志 | 保留实际运行过的 `make` 命令，不改写历史 |

根 Makefile 只在迁移期作为现有行为基线。新入口达到功能对等并通过关闭门禁后，删除根
Makefile，README、workflow 和活动任务全部切换为 `just`。固定 submodule 自带的
`tests/cdp/Makefile` 可以继续由仓库脚本内部调用；这是后端实现细节，不是公开 CLI，
也不构成第二个仓库级构建接口。

## 公开 CLI 合同

公开命令按验证能力命名，阶段门禁只负责编排这些能力。初始合同如下：

```text
just --list
just doctor
just status
just show-config <config>
just lint <config>
just unit <suite>
just integration <suite>
just trace <config> <case>
just trace-all <config>
just system <suite>
just gate <gate>
just vivado <product> <action>
just export-submission ...
just clean
```

首批稳定配置名：

| 配置 | CPU/主存拓扑 | Cache | 用途 |
| --- | --- | --- | --- |
| `single-basic` | 历史 `Inst_ROM` / `Data_RAM` | 不适用 | Lab 1 回归 |
| `single-axi-direct-bypass` | CPU → Cache bypass → AXI master → 行为级 BRAM | off | AXI 隔离诊断 |
| `single-axi-direct-cache` | CPU → I/D Cache → AXI master → 行为级 BRAM | on | AXI/Cache 隔离诊断 |
| `single-soc-bypass` | CPU → Cache bypass → AXI master → fabric → 行为级 BRAM/MMIO | off | 产品拓扑 bring-up |
| `single-soc-cache` | CPU → I/D Cache → AXI master → fabric → 行为级 BRAM/MMIO | on | 自动化产品主配置 |
| `pipeline-basic` | 当前流水线产品的历史 Basic 路径 | 不适用 | 流水线基线回归 |

配置名解析为只读的完整输入集合，至少包含 product、topology、memory model、Cache
模式、RTL source set、compiler defines、backend 和 artifact directory。recipe 不得再
通过相互覆盖的默认变量暗中改变配置。所有证明性命令执行前必须输出该集合，并对未知
配置或非法组合返回非零状态。

`just` 版本要求由 `just doctor` 检查。实现只使用当前稳定功能，不依赖
`--unstable`。`just --fmt --check` 是 Justfile 自身的格式门禁。

## 验证分层

| 层级 | 输入边界 | 主要证明 | 明确不证明 |
| --- | --- | --- | --- |
| Unit | 单个 RTL 模块 | 局部状态机、协议和边界值 | 跨模块组合 |
| Integration | 一个明确的接口切片 | Cache/AXI/MMIO 等所有者之间的组合合同 | CPU 程序行为、板级时钟/IP |
| Trace | CPU 提交与访存观测 | ISA 行为及指定主存拓扑下的执行正确性 | 五类外设完整行为、物理板 |
| System | CPU 驱动的 SoC 仿真 | 正常程序同时经过 CPU、Cache、AXI、fabric、主存和 MMIO | PLL、XCI 实现、约束和引脚电气行为 |
| FPGA/board | Vivado 产品与 EGO1 | 实现后时序、bitstream 和用户观察 | 不由 RTL 仿真结果替代 |

现有 `soc_stage3_full_tb` 在新体系中归类为
`integration dcache-mmio`，不再作为“完整 SoC”命名依据。现有 Cache、AXI 和外设
定向 testbench 继续保留为 Unit/Integration 证据。

## Product-topology Trace

官方 Trace 仍以 `miniRV_SoC` 为顶层，并直接观察
`miniRV_SoC.U_cpu.U_core` 下的 `ifetch_*`、`debug_wb_*` 和 `debug_mem_*`。本任务必须
保持这一层次和提交语义。

重构后的职责边界为：

- `RUN_TRACE` 只表示官方 Trace driver/public-observation 合同，不再单独决定是否绕过
  产品 fabric；
- 历史 Basic、AXI 直连和 product-topology SoC 由显式配置选择；
- `miniRV_SoC` 继续直接拥有 `U_cpu`，避免改变官方 Trace 层次；
- `soc_interconnect` 与 `soc_peripherals` 组成一份由产品仿真和 Vivado 产品共同复用的
  fabric，不在 testbench 中复制；
- 仿真配置在 fabric 的主存 AXI 边界连接固定 Trace 框架的行为级 `bram_axi`；Vivado
  产品在同一边界连接 canonical XCI；
- 仿真时钟/复位适配与产品 fabric 选择分离，不能继续由一个宏同时改变两者。

`single-soc-bypass` 和 `single-soc-cache` 都要运行 45 项标准 Trace。它们证明普通程序
取指和数据访问经过了系统互连的主存路由，但标准 Trace 程序不因此自动成为 MMIO
测试，也不能被记录为“板级完整验证”。

## CPU 驱动的完整 SoC 系统测试

本间章所说的“完整”严格限定为自动化 RTL 系统仿真：

```text
CPU
  -> ICache / DCache
  -> axi_master
  -> soc_interconnect
  -> behavioral AXI BRAM + soc_peripherals
  -> switch / LED / seven-segment / UART / timer testbench boundary
```

新增仓库自有的小型 SoC smoke program 和自检 testbench，至少满足：

1. 默认使用 `single-soc-cache`，从复位 PC `0x00000000` 正常取指；
2. 对普通主存执行读写，证明 ICache/DCache 回填、命中和写路径仍工作；
3. 由 CPU 指令访问开关、LED、数码管、UART 和计时器，而不是 testbench 直接驱动
   DCache 或 AXI 接口；
4. testbench 驱动确定的开关值和 UART RX 帧，并检查 LED、八个数码管扫描槽、UART TX
   完整帧及计时器读取关系；
5. 证明 MMIO 保持 uncached 单拍访问，普通 Cache miss 保持四拍回填；
6. 程序以明确的内存签名或专用仿真完成信号报告 PASS/FAIL，并具有总周期超时；
7. 测试程序源码、构建命令和二进制生成关系均在仓库内可复现，生成物不提交。

官方 Trace golden model 不作为五类 MMIO 的完整 oracle。本系统测试使用仓库自有
testbench 判断外设效果；标准 Trace 继续负责 CPU 提交和指令行为。非法 AXI 形状、
DECERR 和零副作用仍由 Unit/Integration 测试证明，因为正常 CPU 程序不会生成所有
非法事务。

这个系统测试不包含 PLL、门控时钟、Vivado Block Memory Generator、XDC、实现后时序
或真实 EGO1 I/O，因此不得称为“完整板级测试”。Stage 4 的 C_TEST 和用户实板观察、
Stage 5 的 implementation/bitstream 仍是独立门禁。

## 实施检查点

### I0：接口冻结与基线清单

- 把当前每个根 Make target 解析为产品、拓扑、Cache、后端、输入和产物；
- 建立旧入口到新 Just recipe/config/gate 的一次性迁移表；
- 记录当前已通过的 Stage 3 证据，不因文档或 CLI 迁移重复声称新的运行证明；
- 冻结本任务的公开 CLI、配置名、验证分层和停止条件。

默认写集：本任务书、父任务书和 `docs/devlog/README.md`。

I0 状态：Completed（2026-07-26）。公开 CLI、六个稳定配置、验证分层和停止条件按本文
冻结。`6bad8c6` 至 `5750da8` 之间记录的 Stage 3 PASS 只作为迁移前历史证据，不因
本检查点的文档或 CLI 工作重新计作验证运行。

一次性迁移表如下。新入口必须直接拥有对应工具参数；除固定 Trace submodule 的内部
Makefile 外，不以递归调用旧根 Make target 作为终态。

| 旧根入口 | 解析后的能力 | 新入口 |
| --- | --- | --- |
| `make doctor` / `status` / `help` | 环境、仓库状态、入口发现 | `just doctor` / `status` / `--list` |
| `make lint PRODUCT=... TRACE_PROFILE=... CACHE=...` | 显式产品、主存与 Cache lint | `just lint <config>` |
| `make cache-test` | ICache/DCache bypass 与 enabled unit | `just unit cache` |
| `make axi-test` | AXI master bypass 与 line-mode unit | `just unit axi-master` |
| `make soc-stage3-peripheral-test` | UART、数码管、timer unit | `just unit peripherals` |
| `make soc-stage3-unit-test` | interconnect + 五类 MMIO integration | `just integration fabric-mmio` |
| `make soc-stage3-full-test` | DCache 至 fabric/MMIO integration | `just integration dcache-mmio` |
| `make trace-basic[-all]` | 单周期或流水线历史 Basic Trace | `just trace[-all] single-basic|pipeline-basic` |
| `make trace-axi[-all]` | 单周期 AXI 直连、Cache bypass Trace | `just trace[-all] single-axi-direct-bypass` |
| `make trace-axi-cache[-all]` | 单周期 AXI 直连、Cache enabled Trace | `just trace[-all] single-axi-direct-cache` |
| `make soc-stage2-test` | Stage 2 能力编排 | `just gate single-stage2` |
| `make soc-stage3-test` | Stage 3 能力编排 | `just gate single-stage3` |
| `make check-products` | 双产品 Basic lint/Trace | `just gate products-basic` |
| `make vivado-*` | canonical project staging/synth/bitstream backend | `just vivado <product> <action>` |
| `make export-submission` / `clean` | 提交导出 / 生成物清理 | `just export-submission` / `clean` |
| `cache-lint` / `axi-lint` / `soc-stage3-lint` | 各 suite 的前置 lint | 对应 `just unit` / `integration` 内部门禁 |
| `trace-profile` / `trace-build` / `trace-clean` | Trace 配置切换、构建和清理实现 | `scripts/build.sh` 的加锁内部步骤 |
| `trace-demo` | 七项历史 demo 子集 | 对显式配置逐项执行 `just trace <config> <case>` |
| `check` | 隐式默认 lint + 全 Trace + whitespace | 显式 `just lint`、`trace-all` 与 `gate closure` |

### I1：Just CLI 骨架

- 新增根 `Justfile`，完成 `--list`、`doctor`、`status`、`show-config` 和配置校验；
- 把配置解析集中在一个 owner 中，复杂工具调用落到 `scripts/`；
- 为不同 backend/config 使用明确的 `.cache/` 产物目录；
- 对共享 Trace 状态选择显式串行化或配置隔离方案，禁止并发配置互相清理产物；
- 迁移期可以临时调用旧 Make target 做对照，但不得以此作为检查点终态。

默认写集：`Justfile`、`scripts/`、必要的忽略规则、根 `Makefile` 和 workflow 文档。

### I2：现有能力迁移与对等验证

- 迁移 lint、Cache/AXI/外设测试、三种现有 Trace、双产品检查、Vivado、导出和清理
  入口；
- 新旧入口在相同源树上解析出等价的 source set、defines 和工具参数；
- 新 CLI 的退出状态、失败汇总和帮助文本可由人直接判断；
- 保持 Trace 串行执行，不因 `just --jobs` 或 recipe dependency 意外并发共享的
  `tests/cdp/obj_dir`。

默认写集：I1 写集、`config/` 和现有测试编排脚本。除为适配明确产物目录外，不修改
产品 RTL。

### I3：产品拓扑仿真边界

- 分离 Trace observation、仿真 clock/reset、下游 topology 和 memory model；
- 提取或整理唯一的产品 fabric owner，使仿真和 Vivado 产品复用 interconnect 与外设
  连接；
- 建立 `single-soc-bypass` 与 `single-soc-cache`；
- 保持 `miniRV_SoC.U_cpu.U_core`、复位 PC 和现有 public 信号不变；
- 将新增 RTL/仿真源正确加入 canonical Vivado 工程，但不进入 Windows staging 开发。

默认写集：`projects/single_cycle/src/rtl/miniRV_SoC.v`、必要的新 fabric RTL、
`projects/single_cycle/miniRV.xpr`、`tests/`、`Justfile` 和对应脚本。若需要修改
`cpu_core.v`、Trace public 接口、Cache/MMIO 行为或 submodule，立即停止并重新定界。

### I4：完整自动化系统测试

- 让两种 product-topology 配置通过完整 45 项 Trace；
- 新增 `tests/soc_system/` 下的程序、testbench 和断言；
- 运行 Cache-enabled CPU-driven SoC smoke，覆盖普通主存和五类 MMIO；
- 保留 Stage 3 的定向错误事务、子字、UART、数码管和 timer 深度测试；
- 明确报告 System PASS 与 FPGA/board Not Run 的边界。

默认写集：`tests/soc_system/`、测试程序构建脚本、`Justfile`、必要的仿真适配 RTL 和
本任务书。若系统测试发现产品 RTL 缺陷，先形成独立失败用例和缺陷范围；不得把功能
修复静默混入 CLI 迁移。

### I5：切换与关闭

- 删除根 Makefile，确认仓库公开入口只剩 `just`；
- 更新 README、workflow、活动任务书和开发日志索引中的当前命令；历史记录中的实际
  `make` 证据保持原样；
- 审计 `just --list`、各 recipe usage、配置说明和门禁名称；
- 运行最终关闭矩阵并形成独立 Git 检查点；
- 关闭本间章后才恢复单周期 SoC Stage 4。

I5 状态：Completed（2026-07-26）。根 Makefile 已删除；README、workflow、父任务和
索引已切换到 Just。历史开发记录中的实际 `make` 命令保持原样。I0～I4 的实现检查点
为 `b616e4a`（`build: add explicit just verification workflows`）；I5 的独立检查点为包含
本关闭记录的提交。机器相关的 Vivado 路径和并行度也已从 Make 风格的 `local.mk`
迁移到 Git 忽略的 `local.env`；`doctor` 与 Vivado 后端共享同一份白名单解析器，调用者
环境变量保持最高优先级。

## 关闭记录

2026-07-26 运行 `just gate closure` 并通过，关闭证据如下：

- `just --fmt --check`、`just doctor`、六个稳定配置解析和全部六配置 lint 通过；未知配置
  能够以非零状态拒绝；`just --list`、recipe usage、根 Makefile 缺失和当前
  README/workflow 的公开入口另行复核通过；
- Unit 全部通过：ICache、DCache 的 bypass/enabled，AXI master 的一拍/四拍，以及
  UART、数码管和 timer；Integration 的 `fabric-mmio` 与 `dcache-mmio` 通过；
- `single-basic`、`single-axi-direct-bypass`、`single-axi-direct-cache`、
  `single-soc-bypass`、`single-soc-cache` 和 `pipeline-basic` 的完整 Trace 均为
  45 passed、0 failed；Trace 通过文件锁串行使用共享 `tests/cdp/obj_dir`；
- Cache-enabled CPU-driven SoC smoke 通过：复位 PC 为 `0x00000000`，观察到 ICache 与
  DCache 四拍回填，主存 write-through 与 cached load 正确；366 次 MMIO read 和 3 次
  MMIO write 均为单拍，并验证 switch、LED、八个数码管扫描槽、UART RX/TX 完整帧和
  timer；
- `xmllint --noout projects/single_cycle/miniRV.xpr`、`git diff --check` 和全部 shell
  脚本语法检查通过；关闭矩阵后运行 `just clean`，成功清理仓库生成物；
- Vivado 2023.2 `single_cycle` synthesis 通过：99 infos、46 warnings、0 critical
  warnings、0 errors。综合后 50 MHz CPU 时钟 WNS 为 1.344 ns、TNS 为 0.000 ns，综合
  时序约束满足；资源为 3746 Slice LUTs、1755 Slice Registers、12.5 Block RAM Tiles
  和 0 DSPs。以上仅为 synthesis 证据；
- `just export-submission` 的缺失身份/报告/程序输入拒绝路径通过；实际提交包导出为
  **Not Run**。Vivado implementation、bitstream、Stage 4 C_TEST 和实际板测均为
  **Not Run**，System PASS 与 synthesis PASS 不替代这些后续门禁。

## 关闭门禁

间章只有在以下项目全部满足后才能标记 Completed：

- `just --fmt --check`、`just --list`、`just doctor` 和全部配置解析检查通过；
- 现有 Cache、AXI、interconnect、五类外设 Unit/Integration 测试通过；
- `single-basic`、`single-axi-direct-bypass`、`single-axi-direct-cache`、
  `single-soc-bypass`、`single-soc-cache` 各自的 lint/Trace 要求通过，所有完整 Trace
  均为 45/45；
- CPU-driven `single-soc-cache` 系统测试通过，并输出可审计的功能摘要；
- `pipeline-basic` lint 和完整 Trace 保持通过；
- `xmllint --noout projects/single_cycle/miniRV.xpr` 与 `git diff --check` 通过；
- 若 I3 修改了产品 RTL、顶层或 Vivado 工程，重新运行 Vivado 2023.2 synthesis 并
  记录 error、critical warning、资源和综合后时序；
- 根 Makefile 已删除，当前 README/workflow 不再把 `make` 作为公开入口；
- 文档明确记录 implementation、bitstream、C_TEST 和实际板测为 Not Run。

## 停止条件

出现以下任一情况时停止当前检查点并请求重新定界：

- 需要修改指导书或 Trace submodule；
- 需要改变 `miniRV_SoC.U_cpu.U_core` 层次、Trace public 信号或提交时序；
- 需要改变 CPU ISA、Cache/MMIO 当前有效合同或两份设计 CSV；
- 需要提前进入 C_TEST 身份内容、正式 COE、bitstream 或用户板级观察；
- product-topology 仿真只能通过复制产品 RTL 或修改 Windows staging 实现；
- 新旧入口对同一配置产生无法解释的 source/define/tool 参数差异；
- 删除根 Makefile 前尚有能力未迁移或 pipeline 基线未证明；
- 为追求并行速度需要并发写入共享的 `tests/cdp/obj_dir` 或其他非隔离产物。

## 完成后的交接

完成后，单周期 SoC Stage 4 只通过新的 Just CLI 使用已经验证的
`single-soc-cache` 产品配置。C_TEST 程序构建应接入同一程序/镜像接口，但其内容、
Vivado bitstream 和用户实板观察仍由 Stage 4/5 分别拥有，不在本间章预先实现或声明。
