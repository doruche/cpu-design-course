# 单周期 RTL 清理与微重构任务书

## 状态

- 状态：Done
- 建立日期：2026-07-23
- 完成日期：2026-07-23
- 基线提交：`308c8c7f1d9ec0961a9fa78d913a3ed1e97fd196`
- 产品：`projects/single_cycle/`
- 性质：行为保持型清理；SoC 实现前置任务
- 实现状态：已完成

本文是本次重构的范围、顺序和验收依据。课程行为仍以固定版本的指导书和 Trace
框架为准；指令级设计仍以 `design/single_cycle/datapath.csv` 和
`design/single_cycle/control_signals.csv` 为准。

## 背景与判断

Lab 1 单周期 CPU 已完成全部 Basic Trace，并由 `lab1-complete` tag 保存。下一步
将把该产品演化为带 Cache、AXI、共享主存和外设的单周期 SoC。当前 RTL 没有已知
的功能性阻塞，但存在以下维护负担：

- `cpu_core.v` 同时承担读取调度、长延迟操作跟踪、访存请求寄存、写回和 Trace
  观测，内部完成事件和寄存器命名不够直接；
- `Controller.v` 先定义每条指令的布尔量，再通过多组大规模 OR 表达式生成控制
  信号，单条指令的完整控制语义不容易核对；
- lint 配置保留了已经不再触发的旧豁免，核心中也有死信号、过宽寄存器和
  `casex`；
- Vivado 行为仿真 testbench 的端口宽度和顶层已经发生漂移。

标准 `make lint` 在任务建立时通过。无豁免 lint 暴露的是以上清理项以及尚未接入
外设造成的预期顶层告警；本任务不把这些告警解释为新的功能错误。

## 目标

1. 让普通指令、访存指令和乘除法指令的接收、等待、完成、写回关系能从
   `cpu_core.v` 的命名和结构直接读出。
2. 让 `Controller.v` 的译码结构可以逐条对应控制信号 CSV，而不依赖跨越文件大段
   代码的指令集合推理。
3. 删除明确的死代码和已失效 lint 豁免，修复可以无行为变化消除的 lint 问题。
4. 恢复与当前 EGO1 顶层一致的 Vivado 行为仿真入口，为后续 AXI `lw` / `sw`
   仿真准备可信脚手架。
5. 为后续 SoC 集成提供更清晰的 CPU/存储边界，不在本任务中提前实现 SoC。

## 必须保持的不变量

### 外部与工具契约

- 保持层次名 `miniRV_SoC.U_cpu.U_core`。
- 不改动 `ifetch_req`、`ifetch_addr`、`ifetch_valid` 以及所有
  `debug_wb_*`、`debug_mem_*` 的名称、位宽、`/* verilator public */` 标记和可见
  层次。
- 不修改 `RUN_TRACE` 保护的观测语义，不修改 `cdp-tests/`。
- 复位 PC 保持 `0x00000000`。Trace 顶层复位保持高有效，EGO1 FPGA 边界复位保持
  低有效。
- 课程提交 RTL 继续使用可综合 Verilog `.v` / `.vh`；SystemVerilog 仅用于仓库自有
  testbench。

### CPU 行为

- 保持当前首个取指请求和后续取指请求的相对时序，不增加预取或多请求并发。
- 保持 `ifetch_valid` 到普通指令完成、PC 更新、寄存器写回和 Trace 提交的现有
  周期关系。
- 保持访存请求的地址、字节使能、写数据对齐和单请求在途语义；Load 由
  `daccess_rvalid` 完成，Store 由 `daccess_wresp` 完成。
- 保持访存和乘除法开始时对目标寄存器、访存扩展方式和字节偏移的捕获语义。
- 保持乘除法运算结果、除零行为和完成周期；本任务不修改 `ALU.v`、
  `multiplier.v` 或 `divider.v`。
- 保持未识别指令无寄存器/存储器副作用并前进到 `PC + 4` 的现有行为。
- 保持当前非对齐 Load/Store 的请求抑制行为；本任务不引入异常或新的兼容语义。

### 设计与仓库边界

- 本任务不改变指令级数据通路或控制语义，因此两张设计 CSV 是只读核对依据。
- `complete_datapath.drawio` 是里程碑展示产物，不随内部信号改名更新。
- 不修改指导书和 Trace 两个 submodule，不在 `cdp-tests/mySoC/` 或 Windows staging
  中开发。
- 保留用户无关改动；不借机统一旧模板的换行符、缩进或文件编码。

## 明确非目标

- 不接入 ICache、DCache、`axi_master`、AXI BRAM、Crossbar 或外设。
- 不拆分或重命名 `cpu_core`、`Controller`、`ALU` 等现有模块。
- 不把 CPU 改写成新的显式 FSM，不改变现有流水节拍或完成协议。
- 不重写乘法器、除法器或 ALU，不做性能、面积和频率优化。
- 不改变模块外部端口命名，不全面迁移到 `_i` / `_o` 风格。
- 不处理即将被 SoC 主存路径替换的 `Inst_ROM` / `Data_RAM` 地址截断告警。
- 不用常量临时驱动尚未实现的 LED、数码管和 UART 顶层端口。
- 不进行板级验证，不声明 Vivado、时序或硬件结果，除非相应步骤实际运行。

## 执行规则

1. 按 Checkpoint 0、1、2、3 的顺序执行；前一检查点的门禁未通过时不得进入下一
   检查点。
2. Checkpoint 1～3 各形成一个独立提交，避免把结构调整、译码调整和仿真工程调整
   混在同一差异中。
3. 每个检查点的 write set 是默认硬边界。若现有文件边界迫使实现产生重复状态、
   旁路或不清晰适配层，应先停止并在本文“Write Set 扩展记录”中说明原因、拟增加
   的文件和验证影响，获得确认后再继续。
4. 重构只允许等价替换。若发现代码、设计 CSV 与 Trace 之间存在真实语义分歧，
   停止当前检查点，将其作为独立正确性问题报告，不得夹带修复。
5. 自动化检查由代理负责；物理下板和板上现象由用户负责。

## Checkpoint 0：建立实施基线

### Write set

无。该检查点只读。

### 工作

- 确认 worktree 中没有与本任务冲突的用户改动。
- 运行标准 lint 和完整 Basic Trace，记录实施前基线。
- 运行一次不带仓库豁免的 Verilator lint，区分有效问题、官方 RAM 模型告警、即将
  被 SoC 替换的旧存储包装告警和暂未接入外设的顶层告警。
- 核对 Trace 驱动对层次、public 信号和提交时序的直接引用。

### 验证门禁

```bash
make lint
make trace-all
git diff --check
```

若标准 lint 或任一 Trace 在无源码改动时失败，停止任务并先诊断基线。

## Checkpoint 1：核心可读性与 lint 清理

### Write set

- `projects/single_cycle/src/rtl/cpu_core.v`
- `projects/single_cycle/src/rtl/MREQ.v`
- `config/verilator-single_cycle.vlt`

### 工作

- 删除未驱动且未使用的 `rf_rd3`。
- 将只消费低两位的 `alu_c_r` 收窄并重命名为表达访存字节偏移的寄存器。
- 将 `ld_st_flag`、`mul_div_flag`、`rf_we1`、`rf_wR_r` 等内部名称整理为能表达
  pending、done、commit 和 captured 值的名称；只改内部标识符，不改接口。
- 为“普通指令完成”“访存完成”“乘除法完成”“提交写回”建立集中、具名的组合
  事件，复用现有布尔方程，不移动寄存器边界。
- 用显式优先级的 `if` / 普通 `case` 替换写回选择中的 `casex`。
- 为 `MREQ` 写请求译码补充显式 `default`，保持既有默认输出。
- 更新注释，使其说明请求/完成协议和状态所有权，不逐行复述代码。
- 只删除已由无豁免 lint 证明不再触发的规则；保留有明确模板、IP 或阶段性原因的
  豁免。

### 禁止夹带

- 不修改 `cpu_core` 的端口、实例名和子模块连接。
- 不改变 `always` 块的时钟/复位边沿，不引入新的状态机。
- 不修改 `Controller.v`、`ALU.v`、`Inst_ROM.v` 或 `Data_RAM.v`。

### 验证门禁

```bash
make lint
make trace TEST=jalr
make trace TEST=lw
make trace TEST=sw
make trace TEST=mul
make trace TEST=div
make trace-all
git diff --check
```

### 停止条件

- 任一 Trace 的写回/访存可见周期发生变化；
- 等价整理需要改变取指或访存协议；
- 需要修改 Trace public 信号或层次；
- 需要引入新的 CPU 状态。

## Checkpoint 2：Controller 译码整理

### Write set

- `projects/single_cycle/src/rtl/Controller.v`

只读核对：

- `design/single_cycle/control_signals.csv`
- `design/single_cycle/datapath.csv`
- `projects/single_cycle/src/rtl/defines.vh`

### 工作

- 保持 `Controller` 模块接口和所有宏编码不变。
- 将当前“指令布尔量 + 多组 OR 分类”整理为具有完整默认值的组合译码。
- 优先按 `opcode` 分类，再按 `funct3` / `funct7` 使用普通 `case` 细分；所有组合
  分支必须有 `default`。
- 每条支持指令的输出应能直接与控制信号 CSV 的对应行核对。
- 未识别编码必须得到确定的无副作用控制值。
- 不使用依赖字段位置记忆的打包“魔法控制字”，不使用 `casex`。

### 审查要求

- 逐行核对全部 demo、group A 和 group B 指令。
- 特别复核共享编码族：移位立即数、R 型基础指令与 M 扩展、Load/Store、条件分支。
- 特别复核 `AUIPC`、`JALR`、字节/半字访存以及有符号/无符号乘除法。

### 验证门禁

```bash
make lint
make trace TEST=srai
make trace TEST=auipc
make trace TEST=sb
make trace TEST=jalr
make trace TEST=mulhu
make trace TEST=remu
make trace-all
git diff --check
```

### 停止条件

- CSV 与当前已验证 RTL 对同一指令给出不同语义；
- 译码整理要求改变任一控制宏的编码；
- Trace 失败无法证明是纯粹的等价重构错误。

发现上述情况时，不更新 CSV 或顺手改变行为；先形成单独的问题说明并等待决策。

## Checkpoint 3：Vivado 行为仿真脚手架整理

### Write set

- `projects/single_cycle/src/sim/soc_simple_tb.v`
- `projects/single_cycle/miniRV.xpr`
- `projects/single_cycle/soc_simple_tb.wcfg`，仅在确认信号路径失效时修改

### 工作

- 将 testbench 的拨码开关、LED 和数码管端口宽度与当前 EGO1 顶层对齐。
- 补齐 `dig_seg1` 等当前顶层端口连接。
- 澄清 testbench 中板级低有效复位的命名和驱动，不改变产品复位逻辑。
- 确保 testbench 只属于 Vivado simulation fileset，不作为综合或实现输入。
- 删除 `.xpr` 中确认不存在的旧 waveform 配置引用；保留仍有效的当前 WCFG。
- 保持当前程序结束判据，除非实际仿真证明它已失效。

### 禁止夹带

- 不为通过仿真而修改 `miniRV_SoC.v`、时钟 IP、ROM/RAM RTL 或 COE 内容。
- 不新增 AXI、Cache 或外设仿真逻辑。
- 不把 Windows staging 产生的变化复制回仓库。

### 验证门禁

```bash
make lint
make trace-all
make vivado-stage
git diff --check
```

随后用 Vivado 2023.2 对 canonical `.xpr` 实际执行行为仿真的编译、展开和运行，并在
本文完成记录中写明命令和结果。若当前环境不能运行 Vivado，应明确记录“未运行”，
不得以静态检查代替 Vivado 验证结论。

### 停止条件

- 修复 testbench 必须改变产品顶层 RTL 或 IP 配置；
- 仿真失败暴露出 Lab 1 产品行为问题，而非脚手架漂移；
- 需要新增根构建命令或修改 Vivado 自动化脚本。此类需求应先申请 write set 扩展。

## 已知延后项

- `Inst_ROM.v` / `Data_RAM.v` 到 RAM 宏的地址宽度截断：这些模块将在单周期 SoC
  主存切换时退出产品路径，本任务不为消除临时告警改写其地址语义。
- `miniRV_SoC.v` 尚未使用或驱动的开关、LED、数码管和 UART 端口：由后续外设
  集成负责，不添加临时常量。
- `fpga_rst` 的 Trace/板级同步与异步使用告警：保持现有模式边界，留待 SoC 顶层
  时钟复位设计统一审查。
- 旧 RTL 的 CRLF/LF 混合：不做整库格式化，避免掩盖语义差异。
- 本地 Cache 材料中的乱码注释：在后续 Cache 导入 canonical RTL 时单独转码和
  审查，不修改材料快照。

## 总体验收

- 三个实现检查点均为边界清晰的独立提交。
- `make lint` 通过，仓库 lint 豁免只保留仍可复现且理由明确的项目。
- 全部 45 项 Basic Trace 通过，包括 `start`。
- `git diff --check` 通过，没有无关格式化和 submodule 修改。
- Trace 层次、public 信号、复位 PC、访存字节语义和长延迟完成语义未改变。
- Vivado 行为仿真实际通过，或明确记录为未运行；不得扩大为综合、实现、时序或
  板级验证声明。
- 本文状态更新为 Done，并填写各检查点的提交与验证证据。

## 完成记录

| Checkpoint | 状态 | 提交 | 验证证据 |
| --- | --- | --- | --- |
| 0 基线 | Done | — | `make lint`；`make trace-all` 45/45；无豁免 lint 17 项完成分类；`git diff --check` |
| 1 核心清理 | Done | `54367c6` | `make lint`；`jalr` / `lw` / `sw` / `mul` / `div`；`make trace-all` 45/45；无豁免 lint 降至 13 项，仓库配置仅保留对应 13 条有效豁免；`git diff --check` |
| 2 Controller | Done | `46d5438` | `make lint`；`srai` / `auipc` / `sb` / `jalr` / `mulhu` / `remu`；`make trace-all` 45/45；非法编码 131072 种组合穷举通过；`git diff --check` |
| 3 仿真脚手架 | Done | `b0ac3e7` | testbench Verilator 静态编译；`make lint`；`make trace-all` 45/45；`make vivado-stage`；Vivado 2023.2 行为仿真通过；`git diff --check` |

Checkpoint 3 的 Vivado 验证在 `/mnt/z/cpu-design-vivado/single_cycle` staging 工程上
执行。批处理通过 `open_project`、`update_compile_order -fileset sim_1`、
`launch_simulation -simset sim_1 -mode behavioral` 和 `run 100 us` 完成编译、展开与
运行；testbench 于 `11480100 ps` 输出 `Test Passed!` 并调用 `$finish`。未运行综合、
实现、时序分析或板级验证。仿真中的两项 RAM `addra` 位宽告警属于本文“已知延后
项”记录的旧存储包装告警。

## Write Set 扩展记录

当前无扩展。

后续扩展必须记录：原 write set 为何会导致错误分层或重复适配、拟增加的文件与模块
边界、对不变量和验证门禁的影响、确认结论及日期。
