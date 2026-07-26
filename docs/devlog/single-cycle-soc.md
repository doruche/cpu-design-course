# 单周期 SoC 开发任务书

## 状态

- 状态：Active
- 建立日期：2026-07-26
- 基线提交：`87f2f3c`
- 产品：`projects/single_cycle/`
- 当前阶段：Stage 1 已完成；Stage 2 未开始

本文记录单周期 SoC 开发的总体方向和阶段顺序。课程要求仍以固定版本的指导书、
Trace 框架和课程验收说明为准；各阶段的具体接口、实现方案和验证安排在进入该阶段
时根据当前代码单独确定，不在本任务书中提前固化。

## 目标

在已经完成的单周期 CPU 基础上，逐步形成一套可独立维护和构建的单周期 SoC：

- 保留现有单周期 CPU 的完整指令能力；
- 建立 Cache、AXI 和共享主存路径；
- 接入课程要求的内存映射外设；
- 支持 C_TEST 0～2 的板级运行；
- 完成单周期 SoC 的 Trace、Vivado 和课程检查准备；
- 保存可复现的单周期 SoC 里程碑，供后续流水线 SoC 集成使用。

## 总体边界

- 产品 RTL 只在 `projects/single_cycle/src/rtl/` 中维护，Vivado 工程配置在
  `projects/single_cycle/` 中维护。
- 保持 `miniRV_SoC.U_cpu.U_core` 层次和 Trace 可见接口，不在 SoC 集成过程中
  无必要地改写已经完成的 CPU 核心。
- `materials/lab2/` 中的文件是课程材料和本地输入，不作为产品 RTL 的第二份真相源。
- 不修改指导书和 Trace submodule，不在 `cdp-tests/mySoC/` 或 Windows staging 中
  开发。
- 自动化构建与仿真由仓库侧完成；烧录和板上现象由用户观察并反馈。
- 本任务只覆盖单周期 SoC。流水线 CPU、流水线 SoC、CoreMark、LLAMA2 和后续性能
  优化仍属于完整课程目标，但在本任务结束后另行推进。

## 阶段路线

### Stage 0：任务准备

- 整理新引入的 ICache、DCache 和验收材料，记录来源与当前状态。
- 核对 Cache、CPU 访存边界、Trace 构建入口和 Vivado 工程现状。
- 明确单周期 SoC 后续阶段的代码归属和开发入口。

### Stage 1：Cache 基线

- 将 ICache、DCache 整理为仓库内可维护的产品 RTL。
- 先独立处理 Cache 自身的问题，再准备与 CPU 和总线连接。
- 保留可关闭 Cache 的开发路径，供后续总线调试使用。

### Stage 2：AXI 主存路径

- 将单周期 CPU 的原有片上 ROM/RAM 路径演进为 Cache、AXI 控制器和共享主存路径。
- 先建立基本 AXI 访存能力，再完成 Cache 接入后的整体联调。
- 同步整理 Basic Trace 与 AXI Trace 的仓库入口，保持两类历史能力可区分。

### Stage 3：I/O 与 SoC 互连

- 建立主存与外设共享的系统互连。
- 接入拨码开关、LED、数码管、UART 和计时器五类课程要求外设。
- 统一维护外设地址约定、CPU 的 uncached 访问和板级顶层连接。

### Stage 4：C_TEST 与板级联调

- 完成 C_TEST 0～2 中与当前 EGO1、miniRV 配置相关的内容。
- 先确认测试程序和外设使用方式，再在自己的单周期 SoC 上联调。
- 将自动化结果与用户完成的实际板级观察分别记录。

### Stage 5：单周期 SoC 收尾

- 完成 Vivado 综合、实现、时序和板级工程收尾。
- 对照课程检查内容整理数据通路、代码说明和报告所需证据。
- 清理临时开发入口，更新仓库状态说明并保存单周期 SoC 里程碑。

## 推进规则

1. 按 Stage 0 至 Stage 5 顺序推进，不把尚未稳定的主存路径、Cache 和外设同时作为
   首次联调对象。
2. 每个阶段开始时，再结合当前代码确定该阶段的任务拆分、实现选择和验证方式。
3. 一个阶段中发现的跨阶段问题先记录归属；除非阻塞当前阶段，不提前扩大实现范围。
4. 阶段完成情况以实际代码和已运行结果为准，不用计划、静态检查或未执行的板级步骤
   代替完成声明。
5. 每个主要阶段形成独立、可回退的 Git 检查点；具体提交划分由阶段内工作决定。

## 当前进度

- Stage 0：已完成，2026-07-26。
- Stage 1：已完成，2026-07-26。
- Stage 2～Stage 5：未开始。

## 阶段记录

### Stage 0：任务准备

状态：Completed（2026-07-26）

本阶段确认了以下上下文：

- `lab1-complete` 继续保存 Lab 1 状态，单周期 SoC 在当前
  `projects/single_cycle/` 产品上演进；流水线产品不属于本阶段 write set。
- 新增的 `materials/lab2/ICache.v`、`DCache.v` 是用户提供的先前课程实验源码快照；
  原始文件保留在忽略目录中，哈希记录在 `materials/MANIFEST.md`。
- 两份原始 Cache 文件使用 GB18030 中文注释和 CRLF 换行。ICache 可独立展开，
  DCache 中的测试探针存在组合环，均需要整理后才能成为产品 RTL。
- 当前 CPU 仍通过 `Inst_ROM`、`Data_RAM` 工作；现有 Trace 入口仍是 Basic Trace。
  AXI 主存、总线桥和外设 IP 尚未进入单周期 Vivado 工程。
- CPU 请求/响应边界已经能等待变长的取指、Load 和 Store 完成，Stage 1 不需要修改
  `cpu_core.v`、Trace public 信号或设计 CSV。

Stage 1 handoff：保持 Cache 现有外部端口、1 KiB 直接映射结构、128 位 Cache line、
写直达和 `0xFFFF_xxxx` uncached 方向；在 canonical RTL 中去除原始测试探针，保留
`ENABLE_ICACHE` / `ENABLE_DCACHE` 控制的旁路路径，并用仓库自有 testbench 独立
验证。`cpu_top` 接入、AXI 控制器和 Trace 配置切换留给 Stage 2。

### Stage 1：Cache 基线

状态：Completed（2026-07-26）

本阶段完成了以下工作：

- 从材料快照整理出 UTF-8、LF、可综合 Verilog 版本的 `ICache.v` 和 `DCache.v`，
  并把它们加入单周期产品的 canonical RTL 与 Vivado Design Sources。
- ICache 保留旁路模式，并在启用后提供直接映射的查找、缺失请求、整行回填和复位
  失效流程。
- DCache 保留旁路模式，并在启用后提供读缺失回填、写直达、不写分配、命中字节
  掩码更新和外设地址 uncached 流程。
- 删除材料版本中只服务旧 testbench、且会形成组合环的 `dcache_probe`，不把探针
  结构带入产品 RTL。
- 新增 `make cache-lint` 和 `make cache-test`，用仓库自有 SystemVerilog testbench
  分别覆盖 ICache/DCache 的旁路与启用配置；生成物统一进入忽略的 `.cache/`。

本阶段验证记录：

- `make cache-test`：四种配置均通过；包括请求 backpressure、回填/命中、替换、
  reset 失效、DCache 写命中、写不分配、字节掩码和 uncached 访问。
- `make lint PRODUCT=single_cycle`：通过。
- `make trace-all PRODUCT=single_cycle`：Basic Trace 45 项通过、0 项失败。
- `make doctor`：通过；Vivado 2023.2 batch 入口可用。
- `xmllint --noout projects/single_cycle/miniRV.xpr`：通过。

Stage 2 handoff：Cache 尚未实例化到 `cpu_top`，两个 enable 宏仍保持关闭，当前产品
继续使用 `Inst_ROM` / `Data_RAM` 并运行 Basic Trace。Stage 2 需要实现总线控制器和
主存连接后再切换该边界。Cache 的读请求在 ready 前保持稳定；总线接受写请求后需
先撤销 ready，并在写完成时重新置位。整行回填以最低 32 位对应块基址，旁路及
uncached 读响应使用返回值最低 32 位。

本阶段没有运行 AXI Trace、Vivado 综合或板级测试；这些结果不属于 Stage 1 的完成
声明。
