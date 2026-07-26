# 单周期 SoC 开发任务书

## 状态

- 状态：Active
- 建立日期：2026-07-26
- 基线提交：`87f2f3c`
- 产品：`projects/single_cycle/`
- 当前阶段：Stage 3 已完成；Stage 4 未开始

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
- Stage 2：已完成，2026-07-26。
- Stage 3：已完成，2026-07-26。
- Stage 4～Stage 5：未开始。

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

### Stage 2：AXI 主存路径

状态：Completed（2026-07-26）

本阶段把范围限定为 Cache、AXI master 和共享主存，不包含 Stage 3 的 AXI
Crossbar、五类外设与 I/O 地址译码，也不包含 Stage 4 的 C_TEST。CPU 现有的
请求/完成握手已经能等待变长访存，本阶段没有改变 ISA 数据通路、控制信号或 Trace
public 信号，因此没有修改两份设计 CSV。AXI master 状态转换图按当前开发安排延期到
整个单周期 SoC 完成后的课程检查产物，不在 Stage 2 提前绘制。

本阶段完成了以下工作：

- 新增状态机式 `axi_master`，在共享端口空闲时按 DCache 写、DCache 读、ICache
  读的顺序接受一个请求。读通道支持 Cache 旁路时的单拍访问和 Cache 启用时的
  4 拍整行回填；写地址与写数据握手分别跟踪，并在两者都完成后等待 B 响应。
- `cpu_top` 的默认产品路径切换为 `cpu_core -> ICache/DCache -> axi_master`；
  `BASIC_TRACE` 显式保留 Lab 1 的 `Inst_ROM` / `Data_RAM` 历史路径，避免用一套
  构建入口混淆两种主存模型。
- `miniRV_SoC` 在 AXI Trace 中连接固定 Trace 框架提供的行为级 `bram_axi`，在
  Vivado 产品中连接 canonical Block Memory Generator IP；两条路径都保持
  `miniRV_SoC.U_cpu.U_core` 层次不变。
- 新增 `bram_axi.xci`：AXI4 Full、32 位数据、12800 深度、Simple Dual Port RAM，
  使用 `lw.coe` 初始化。Vivado 工程已经纳入 `axi_master.v`、该 IP fileset 和对应
  OOC run。
- 非 Trace 的板级产品默认启用 ICache 和 DCache。为保持 RAM 推断，两个 Cache 的
  payload/tag 写入从异步复位进程分离，复位仅清除 valid 位。
- 新增 AXI master 独立 testbench，并把 Basic、AXI Cache 旁路、AXI Cache 启用三种
  Trace profile 分开；profile stamp 会在宏配置变化时清理共享的
  `cdp-tests/obj_dir`。`make soc-stage2-test` 汇总本阶段全部自动化门禁。

本阶段验证记录：

- `make soc-stage2-test`：通过。AXI master 的 1 拍/4 拍配置均通过，ICache/DCache
  的四种旁路/启用配置均通过，Basic、AXI Cache 旁路和 AXI Cache 启用三种 lint
  配置均通过。
- 同一门禁中的三轮完整 Trace 各通过 45 项、失败 0 项：历史 Basic、AXI Cache
  旁路、AXI Cache 启用。
- `make check-products`：single-cycle 与 pipeline 的 Basic lint 和完整 Trace 均通过，
  两套产品各 45 项、失败 0 项；仓库级 profile 选择没有改变 pipeline 基线。
- `xmllint --noout projects/single_cycle/miniRV.xpr`：通过；`bram_axi.xci` 的 JSON
  结构检查通过，工程引用使用 canonical 相对路径。
- Vivado 2023.2 综合完成，0 error、0 critical warning。工程中的 CPU 生成时钟为
  50 MHz；综合后 timing summary 的 overall WNS 为 1.344 ns、TNS 为 0。资源报告
  为 3429 Slice LUT、1463 Slice Register、12.5 Block RAM Tile、0 DSP。综合日志
  同时确认 ICache/DCache 的 data/tag 数组被推断为分布式 RAM，而不是展开为大量
  触发器。

本阶段没有运行 Vivado implementation、bitstream 生成或板级测试，也没有验证任何
Stage 3 外设行为；综合后正时序裕量不能替代实现后时序和实际 EGO1 观察。

Stage 3 handoff：当前 `axi_master` 只连接一个 AXI BRAM 从设备，Cache 已保留
`0xFFFF_xxxx` uncached 访问方向。下一阶段需要在不破坏当前三种 Trace profile 的
前提下加入系统互连、主存路由和五类内存映射外设；本阶段完成不自动启动 Stage 3。

### Stage 3：I/O 与 SoC 互连

状态：Completed（2026-07-26）

本阶段对照指导书把范围确定为系统地址路由、五类外设 RTL 和 EGO1 顶层连接；
不包含 C_TEST TODO、程序镜像切换、implementation、bitstream 或实际下板。外设接入
没有改变 ISA 数据通路、控制器或 Trace public 接口，因此本阶段没有修改单周期 CPU
的两份设计 CSV。

本阶段完成了以下工作：

- 新增可综合的 `soc_interconnect`，承担指导书中总线桥的角色。它将最高 64 KiB
  `0xFFFF_0000～0xFFFF_FFFF` 路由到单拍 MMIO，其余地址继续转发到 AXI BRAM；
  主存读突发保持 AXI 元数据和逐拍响应，写地址与写数据通道继续独立握手。
- 沿用 DCache 已验证的 `0xFFFF_xxxx` uncached 路径：外设读不分配 Cache，保持原始
  地址并只请求/接收一个 32 位数据拍；外设写按 CPU 产生的字节 strobe 直达总线。
- 新增 `soc_peripherals`，统一实现课程地址表与设备选择：开关
  `0xFFFF_0000`、LED `0xFFFF_1000`、数码管 `0xFFFF_2000`、UART
  `0xFFFF_3000～0xFFFF_300C`、计时器 `0xFFFF_4000/0xFFFF_4008`。不存在的端口和
  非法访问返回 AXI DECERR，而不是误落到主存。
- LED 和数码管输出寄存器支持 AXI 字节写掩码。八位数码管按 32 位十六进制值动态
  扫描，并按 EGO1 的位选/段选高电平有效约定驱动；两组四位数码管共享段码。
- UART 使用 50 MHz 时钟、115200 baud、8N1 串行格式和各 16 字节的 RX/TX FIFO。
  四个寄存器的地址及状态/控制位兼容课程 C_TEST 所使用的 AXI UARTLite 约定：
  RX FIFO、TX FIFO、状态寄存器、清空 FIFO 的控制寄存器。FIFO payload 写入与异步
  复位状态分离，Vivado 最终将两组 FIFO 推断为 16×8 分布式 RAM。
- 计时器是复位后自动递增的 64 位计数器，低、高 32 位分别从偏移 `0x000`、`0x008`
  读取。开关、LED、数码管、UART RX/TX 已连接既有 EGO1 顶层端口与 XDC 引脚。
- Trace profile 继续按指导书要求在 `RUN_TRACE` 下直连行为级 AXI BRAM，不引入
  Vivado IP 或物理外设模型；非 Trace 产品才连接系统互连和外设。新增
  `make soc-stage3-lint`、`make soc-stage3-unit-test` 和汇总门禁
  `make soc-stage3-test`。

本阶段验证记录：

- `make soc-stage3-unit-test`：通过。定向覆盖主存/MMIO 路由、AR/R 与独立 AW/W/B
  背压、非法 MMIO 的 DECERR、开关读、LED/数码管读写与字节掩码、64 位计时器、
  UART 状态/控制、TX 串行帧和 RX FIFO 收取/弹出。
- `make soc-stage3-test`：通过；其中 Stage 2 的 Cache 与 AXI master 模块测试、三种
  lint profile 均继续通过，历史 Basic、AXI Cache 旁路、AXI Cache 启用三轮完整
  Trace 各 45 项通过、0 项失败。
- `xmllint --noout projects/single_cycle/miniRV.xpr` 和 `git diff --check`：通过；四个
  新 RTL 文件已加入 canonical Vivado Design Sources。
- Vivado 2023.2 综合完成，最终产品层次包含 ICache/DCache、`axi_master`、
  `soc_interconnect`、五类外设和 AXI BRAM，0 error、0 critical warning。50 MHz CPU
  时钟下综合后 overall WNS 为 1.344 ns、TNS 为 0；资源为 3726 Slice LUT、
  1746 Slice Register、12.5 Block RAM Tile、0 DSP。

本阶段没有运行 Vivado implementation、bitstream 生成、C_TEST 或板级测试。综合后
正时序裕量不等于实现后时序收敛，UART 串行 RTL 仿真也不能替代 EGO1 与上位机的
实际通信观察。

Stage 4 handoff：硬件已经提供 C_TEST 0～2 所需的完整地址与 UARTLite 寄存器语义。
下一阶段需要先完成三套程序中的 UART/TODO 和身份文本，隔离构建并检查 COE，再更新
BRAM 初始化镜像、生成 bitstream，由用户依次观察 UART、开关、LED、数码管和计时
结果；Stage 3 完成不自动启动 Stage 4。
