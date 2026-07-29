# 流水线 merge 后稳定化维护任务书

## 状态

- 状态：Active（M0、M1 已完成；不得自动进入 M2）
- 建立日期：2026-07-29
- merge 基线：`842d5589e12c0ddf303a068c48d3b7ecca45e418`
- 产品：`projects/pipeline/`，以及与双产品共享的仓库维护面
- 性质：行为保持型维护；不是流水线 SoC 产品关闭任务

本文约束 `feat/pipeline` 合入 `main` 后的一轮小型稳定化工作。课程行为仍以固定版本的
指导书和 Trace framework 为准；流水线级间字段、冒险和流控语义仍以
`design/pipeline/` 三份 CSV 为准；ISA 级语义仍以 `design/single_cycle/` 为准。

本任务书冻结范围、顺序、写集和验证门禁。M1 已按 docs-only 边界关闭；M2～M3
仍为 Pending，未获得后续执行指令时不得自动开始实现。

## 背景与实施基线

`github/main` 的 PR #1 已以 merge commit `842d558` 集成到本地 `main`。该基线包含：

- IF/ID、ID/EX、EX/MEM、MEM/WB 四组段寄存器及五级顺序提交核；
- EX/MEM 与 MEM/WB 前递、WB→ID 旁路、load-use stall、EX 分支重定向；
- 无界延迟取指/访存握手、单在途请求、取指 skid buffer 和乘除法等待；
- pipeline Basic、AXI direct、product SoC 的 bypass/cache 配置；
- 从已验证单周期 SoC 移植的 Cache、AXI、interconnect 和外设 fabric；
- CoreMark 单迭代 RTL system suite 与性能计数。

2026-07-29 对该提交的 merge 前后评估得到以下基线证据：

- 全部十个稳定配置 lint 通过；
- 全部十个稳定配置各通过 45 项 Trace，均为 `Passed (45), Failed (0)`；
- cache、AXI master、外设、fabric 集成测试和 `soc-smoke` 通过；
- 当前宿主工具链在 CoreMark 链接时发生 soft-float/libgcc ABI 不匹配；因此本次评估
  没有重现 CoreMark RTL PASS。交接文档中的 CoreMark 数据只保留为原执行者记录；
- pipeline Vivado implementation、50 MHz 时序、bitstream 和 EGO1 板测均为
  **Not Run**。

当前没有已确认的 pipeline RTL 功能错误。本任务的出发点是补足维护证据、消除
merge 后的事实漂移，并在测试保护下进行有界的可读性和所有权整理，而不是重新设计
流水线。

## 目标

1. 让 README、workflow、AGENTS、design 说明、产品基线和 devlog 对 merge 后的
   双产品状态、十配置矩阵和证据边界给出一致陈述。
2. 为 pipeline 特有的 flush、stall、forward、长延迟完成和取指缓冲组合建立定向
   characterization tests，减少只依赖逐指令 Trace 的覆盖盲区。
3. 在测试通过后，整理 pipeline 核心中的状态所有权、完成事件、流控优先级和注释，
   降低后续修改时产生重复请求、重复提交或错误路径副作用的风险。
4. 保持单周期与流水线两个产品各自拥有唯一 canonical RTL，不以共享源码、生成副本
   或 Windows staging 制造第三份真相。

## 必须保持的不变量

### 课程、Trace 与提交契约

- 保持层次 `miniRV_SoC.U_cpu.U_core`。
- 保持所有 `/* verilator public */` 信号的名称、位宽、层次和观测语义。
- `debug_wb_*` 继续表示 WB/架构提交；`debug_mem_*` 继续表示实际生效的存储写。
- reset PC 保持 `0x00000000`；Trace 复位保持高有效，EGO1 FPGA 边界复位保持低有效。
- 不修改 `cdp-tests/` 或 `materials/instruction-site/` 两个 submodule，不在
  `cdp-tests/mySoC/` 中 author RTL。

### Pipeline 行为

- 保持 IF、ID、EX、MEM、WB 五级划分和四组段寄存器边界；保持按程序顺序提交。
- 保持静态预测不跳转、EX 解析和 taken transfer 清除两条年轻指令的语义。
- 保持 load-use、EX/MEM 与 MEM/WB 前递、WB→ID 旁路及 x0 排除规则。
- 保持 IF 和 MEM 各自至多一个在途请求；响应只完成其 owner 持有的请求。
- 保持 fetch discard/skid buffer 在重定向和下游 backpressure 下不丢失正确路径指令，
  也不让错误路径指令提交。
- 保持访存及乘除法等待期间不重复发起请求、不重复写回、不重复产生可见副作用。
- 不改变现有乘除法结果、迭代协议、Cache refill、AXI 或 MMIO 事务语义。

### 仓库与产品边界

- `projects/single_cycle/src/rtl/` 与 `projects/pipeline/src/rtl/` 继续分别拥有两套
  产品的 HDL truth；本任务不引入跨产品 RTL symlink、include 或生成复制。
- `config/build-configs.tsv` 继续是稳定配置矩阵的唯一数据源；本任务不通过新配置
  隐藏既有失败。
- canonical XPR、XCI、XDC、COE 和 Tcl 仍归各产品目录所有；Windows staging 只作
  一次性派生树。
- 不回写、重新格式化或为减少历史 diff 而重排 vendor DDR3 simulation model。

## 明确非目标

- 不实现或关闭 pipeline C_TEST 0～2；该项属于后续流水线 SoC 产品闭环。
- 不修 pipeline Stage 5 COE、XPR、XDC、build Tcl 或 Vivado evidence collector。
- 不运行或声明 pipeline synthesis、implementation、Fmax、bitstream 或板级结果。
- 不创建或移动 milestone tag；本文只允许在文档中记录候选提交和待决 tag 名称。
- 不继续 CoreMark 性能优化，不改变主频、乘法 radix、Cache 参数或访存组合路径。
- 不增加 ISA、异常、中断、动态分支预测、多发射或多请求并发。
- 不拆分公开模块、不改变 CPU–Cache、Cache–AXI 或 MMIO 接口。
- 不把宿主 CoreMark 工具链 ABI 问题与 pipeline RTL 正确性混为一项修复；工具链探针
  若需实现，应另开构建环境维护 checkpoint。

## 执行规则

1. 严格按 M0、M1、M2、M3 顺序执行；前一 checkpoint 未关闭时不得进入下一项。
2. M1～M3 各自形成独立、聚焦提交。文档事实清理、测试基础和 RTL 整理不得混在
   同一个提交中。
3. M2 的 characterization tests 必须先在未修改 RTL 的 `842d558` 行为上通过，才能
   作为 M3 的重构保护。测试若暴露基线缺陷，应停止并单独记录正确性问题；不得为让
   新测试变绿而在 M2 夹带 RTL 修复。
4. M3 只允许有证据支持的等价整理。不得以“架构重整”为由改变寄存器边界、握手、
   流控布尔条件或性能策略。
5. 每个 checkpoint 的 write set 是默认硬边界。需要扩展时，先在本文的 Write Set
   扩展记录中写明原因、目标文件、owner 变化和验证影响，并获得用户确认。
6. 自动化检查由 agent 负责；Vivado GUI、FPGA programming 和板上现象仍由用户负责。

## M0：任务书与范围冻结

状态：Completed（2026-07-29，docs-only；未进入 M1）。

### Write set

- `docs/devlog/pipeline-post-merge-maintenance.md`
- `docs/devlog/README.md`

### 工作

- 记录 merge 基线、当前自动化证据和 Not Run 边界；
- 冻结维护目标、不变量、非目标、checkpoint 顺序和默认写集；
- 将本任务书加入 Active Tasks，但不顺手修复索引中已有的状态冲突。

### 验证门禁

```bash
git diff --check
git status --short
```

M0 只证明任务书本身结构完整，不构成 RTL、CoreMark、Vivado 或板级验证。

## M1：仓库事实与状态文档对齐

状态：Completed（2026-07-29，docs-only）。

### 默认 Write set

- `README.md`
- `AGENTS.md`
- `docs/workflow.md`
- `docs/devlog/README.md`
- `docs/devlog/pipeline-cpu-and-soc.md`
- `projects/pipeline/BASELINE.md`
- `design/pipeline/README.md`
- 本任务书，仅填写执行记录

`config/build-configs.tsv`、RTL、tests、scripts 和 submodule 在 M1 中只读。

### 工作

- 把“pipeline 尚未开始”“仅六配置”“pipeline 只支持 Basic”等陈述更新为 live state；
- 将 `pipeline-cpu-and-soc.md` 从 feature branch 交接改为 merge 后产品状态记录，保留
  历史性能数据并明确其执行提交和证据等级；
- 清理 devlog 索引中同一任务同时 Active/Completed 及“当前无 Active”之类矛盾；
- 更新 `BASELINE.md` 和 pipeline design README，使其不再声称 RTL 未实现；
- 核对现有 tags 的真实可达提交，只记录 pipeline milestone tag 候选，不创建 tag；
- 保留 pipeline C_TEST、物理路径和板级 Not Run，不以措辞把缺口降级为完成。

### 验证门禁

```bash
just --fmt --check
just doctor
git diff --check
```

另以 `rg` 审计已知过期短语。M1 不运行 RTL 门禁，也不得从文档变化推导功能通过。

### 停止条件

- 需要改变课程范围、产品数量、配置语义或已有 RTL/设计合同；
- 无法从提交、live source 或既有执行记录区分某项声明是否成立；
- 文档修正要求同时修改脚本、RTL、XPR/XCI/XDC/COE 或创建 tag。

## M2：Pipeline 定向 characterization tests

状态：Pending。

### 默认 Write set

- `tests/pipeline/` 下新增 repository-owned SystemVerilog testbench/fixture
- `scripts/build.sh`，仅增加一个稳定的 pipeline 定向测试 suite 路由
- `Justfile`，仅暴露上述 suite
- `AGENTS.md`，仅在公开入口清单确需同步时更新
- 本任务书，仅填写执行记录

只读核对：

- `projects/pipeline/src/rtl/`
- `design/pipeline/{stage_registers,hazards,flow_control}.csv`
- `cdp-tests/csrc/` 与现有 45 项 Trace

### 测试范围

新增 suite 默认命名为 `pipeline-control`，从 `cpu_core` 的公开请求、响应和提交边界
驱动可控延迟，不依赖 `force` 内部状态来制造通过。至少覆盖：

1. 连续取指、IF/ID 消费和单项 skid buffer 的满/空边界；
2. taken branch/jal/jalr 与旧路径 fetch response 同周期或相邻周期返回；
3. load→ALU、load→store-data、load→branch 的 stall 与后续前递；
4. EX 被 MEM backpressure hold 时，原前递 producer 下移后的 operand 保持；
5. mul/div 完成与下游暂停重叠时只捕获、提交一次；
6. data read/write response 延迟下只发起一次访问，store 只产生一次可见写；
7. flush、stall 和 response 优先级组合下，错误路径不得产生 RF/内存副作用。

测试应检查架构可见结果和事务计数，避免固定普通无停顿路径的绝对周期数；只有协议
明确要求的相对事件顺序才允许成为断言。

### 验证门禁

```bash
just unit pipeline-control
just lint pipeline-basic
just trace-all pipeline-basic
just lint pipeline-soc-cache
just trace-all pipeline-soc-cache
git diff --check
```

关闭 M2 前，再对另外三个 pipeline 配置执行 lint 和 45 项 Trace：
`pipeline-axi-direct-bypass`、`pipeline-axi-direct-cache`、`pipeline-soc-bypass`。

### 停止条件

- 新测试在未修改 RTL 的 merge 基线上稳定失败；
- 必须窥视或强制非合同内部状态才能表达场景；
- 需要改变 Trace framework、设计 CSV、产品 RTL 或稳定配置语义；
- 测试只能通过放宽“不重复请求/提交”或允许错误路径副作用来成立。

## M3：Pipeline 核心行为保持型整理

状态：Pending；只有 M2 关闭后才可进入。

### 默认 Write set

- `projects/pipeline/src/rtl/cpu_core.v`
- `projects/pipeline/src/rtl/ICache.v`，仅限经 M2 证明属于取指 owner/握手可读性问题
- `projects/pipeline/src/rtl/cpu_top.v`，仅限同步内部信号命名，不改模块接口
- `config/verilator-pipeline.vlt`，仅删除已证明不再触发的 waiver
- 本任务书，仅填写执行记录

`design/pipeline/*.csv` 默认只读。若 live RTL 与 CSV 存在语义分歧，停止 M3；不得在
同一 checkpoint 同时修改实现与合同来制造一致。

### 允许的工作

- 将 fetch、stage advance、flush、load-use、memory completion 和 mul/div completion
  的组合事件整理为集中、具名且 owner 明确的表达；
- 清理已由 lint 和 M2 证明无效的死状态、重复条件或过期注释；
- 统一内部命名，使 pending、issued、returned、discarded、captured、committed
  含义可直接区分；
- 在不改变寄存器边界和布尔方程的前提下，降低同一流控条件在多个 always block 中的
  重复推导；
- 只删除有当前 lint 证据支持的 pipeline waiver。

### 禁止夹带

- 不拆分/合并模块，不新增 adapter、FIFO、旁路、状态机或 outstanding slot；
- 不改变 always block 的时钟/复位边沿或现有 pipeline register 更新条件；
- 不改变请求发起、响应接收、分支重定向、写回或 Trace 可见周期；
- 不修改 ALU、multiplier、divider、Cache 参数、AXI fabric 或单周期产品；
- 不以重构为名修复 M2 发现的功能问题。

### 验证门禁

```bash
just unit pipeline-control
just lint pipeline-basic
just trace-all pipeline-basic
just lint pipeline-axi-direct-bypass
just trace-all pipeline-axi-direct-bypass
just lint pipeline-axi-direct-cache
just trace-all pipeline-axi-direct-cache
just lint pipeline-soc-bypass
just trace-all pipeline-soc-bypass
just lint pipeline-soc-cache
just trace-all pipeline-soc-cache
git diff --check
```

随后必须在仓库固定 devcontainer 中运行：

```bash
devcontainer exec --workspace-folder . just system coremark
```

若固定环境不可用或 CoreMark 未通过，M3 只能记录为自动验证未关闭，不得用 merge 前
性能记录替代本次结果。

### 停止条件

- 任一 characterization test、Trace 提交序列、事务计数或 CoreMark CRC 发生变化；
- 等价整理需要改变接口、段寄存器、flow-control priority 或增加状态；
- 需要修改单周期产品或共享 fabric 才能保持 pipeline 行为；
- 综合/时序顾虑成为结构选择依据。此时应转入独立的物理/性能任务，而非继续 M3。

## 总体验收

- M1、M2、M3 各自以独立、聚焦提交完成，并填写提交和证据；
- merge 后状态文档不存在已知事实矛盾，且未把产品缺口写成完成；
- pipeline-control suite 在原始 merge 基线和整理后 RTL 上均通过；
- 五个 pipeline 配置 lint 与各 45 项 Trace 全部通过；
- 固定 devcontainer 的 CoreMark system suite 通过，或任务保持未关闭；
- Trace/复位/流水线/Cache/AXI/MMIO 合同、单周期产品和两个 submodule 均未改变；
- pipeline C_TEST、Vivado Stage 5、bitstream、板测和最终报告继续由独立任务接手。

## 完成记录

| Checkpoint | 状态 | 提交 | 验证证据 |
| --- | --- | --- | --- |
| M0 任务书冻结 | Completed | `e4dfb8a` | `git diff --check`；docs-only |
| M1 状态对齐 | Completed | 待提交 | `just --fmt --check`；`just doctor`；`git diff --check`；过期短语审计 |
| M2 定向测试 | Pending | — | — |
| M3 RTL 整理 | Pending | — | — |

## Write Set 扩展记录

当前无扩展。

后续扩展必须记录：原 write set 为何不足、拟增加的文件和 owner、是否改变外部或
验证合同、需要新增或重跑的门禁、用户确认结论和日期。
