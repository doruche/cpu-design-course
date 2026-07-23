# Lab 2 需求快照

> 快照日期：2026-07-23
>
> 适用配置：miniRV + EGO1
>
> 指导书版本：`e2748d2b7cd765a19146dff1355cc842ac68fe64`
>
> Trace 版本：`50a818278e9a60d304521c4b16980211b0162014`

本文是课程要求的本地索引和执行快照，不替代指导书。要求发生冲突时，以固定版本的
指导书、Trace 源码和课程提交页面为准；本文不复制指导书正文。

## 结论：Lab 2 不是一条线性改造链

官方教学安排把 Lab 2 分成 A、B 两条可并行的工作流，两条线都从完整的 Lab 1
单周期 CPU 副本开始，达到各自的独立门禁后再汇合：

```text
                            ┌─ A：流水线 CPU ── Basic Trace ─────┐
Lab 1 完整单周期 CPU ───────┤                                   ├─ 流水线 SoC
                            └─ B：单周期 SoC ── AXI Trace/C_TEST ┘  └─ AXI Trace
                                                                       C_TEST
                                                                       CoreMark/LLAMA2
```

因此：

- 可以先完成 A 再完成 B，也可以反过来；两条线之间没有必须固定的先后顺序。
- 不能只维护一个产品并一路覆盖下去，否则会丢失单周期 SoC 或纯流水线 CPU 的独立
  验证点。
- “纯流水线 CPU”是必须通过 Basic Trace 的中间里程碑，不是第三套最终提交物。
- 最终需要保留两套可构建产品：单周期 SoC 和流水线 SoC。

本仓库相应采用两个长期产品目录，而不是课程中的临时 A/B 文件夹：

| 产品目录 | 从哪里开始 | 中间状态 | 最终状态 |
| --- | --- | --- | --- |
| `projects/single_cycle/` | `lab1-complete` | 完整单周期 CPU | 单周期 SoC |
| `projects/pipeline/` | `lab1-complete` 的副本 | 流水线 CPU | 流水线 SoC |

## A 线：流水线 CPU

### 功能要求

- 流水线至少五级，支持 miniRV 全部指令。
- 从完整单周期 CPU 的数据通路切分流水级，并加入段寄存器。
- 先实现理想流水线；这一阶段暂不处理分支、访存、乘除法和数据相关。
- 实现冒险检测。
- 控制冒险使用静态“默认不跳转”预测；预测失败时清空错误路径并修正 PC。
- 实现流水线暂停，覆盖数据冒险、访存等待和多周期乘除法等待。
- 实现数据前递；仍无法前递的数据依赖必须正确暂停。
- 保持完整指令语义和按程序顺序提交的 Trace 可观察结果。

### A 线门禁

| 阶段 | 验证要求 | 通过后得到的状态 |
| --- | --- | --- |
| A1 理想流水线 | 无相关、无访存、无乘除法的独立程序仿真 | 流水级和写回通路成立 |
| A2 冒险处理 | 定向验证分支清空、RAW 检测、暂停与恢复 | 完整流水线可执行全部指令类型 |
| A3 前递 | 定向验证各前递来源和不能前递的依赖 | 性能路径成立且结果正确 |
| A4 Basic Trace | 全部 miniRV Basic Trace 用例通过 | 可供 SoC 集成的流水线 CPU |

Trace 要求保留层级 `miniRV_SoC.U_cpu.U_core`。流水线产品的
`debug_wb_pc`、`debug_wb_rf_we`、`debug_wb_rf_wR`、`debug_wb_rf_wD`
必须反映 WB/提交阶段；存储写调试信号必须反映实际生效的写操作。不要把 IF、ID 或
EX 阶段的推测状态当作提交状态输出。

## B 线：单周期 SoC

### 目标架构

```text
cpu_core
  ├─ 取指接口 ── ICache ─┐
  └─ 数据接口 ── DCache ─┴─ axi_master ── bridge ── 主存/外设
```

要求包括：

- 集成 ICache 和 DCache；其输入来源是先前“计算机组成原理实验 3”的实现，指导书
  本身不提供这两个模块的源码。
- 用状态机实现 AXI4 总线控制器 `axi_master`，覆盖独立的 AR/R 和 AW/W/B 通道。
- 添加总线桥和 AXI 主存。
- 先禁用 Cache 调通 AXI Trace，再分别启用 Cache 重新验证，避免同时调试两个边界。
- 外设采用内存映射 I/O，必须至少实现拨码开关、LED、数码管、UART 和 64 位计时器。
- 完成 C_TEST 0～2 的 TODO；先用课程提供的 SoC 比特流验证程序，再在自己的
  单周期 SoC 上进行下板验证。

### 必须保持的 I/O 地址契约

| 外设 | 地址 | 访问方向/含义 |
| --- | --- | --- |
| 拨码开关 | `0xFFFF_0000` | 只读输入 |
| LED | `0xFFFF_1000` | 写显示数据 |
| 数码管 | `0xFFFF_2000` | 写显示数据 |
| UART RX FIFO | `0xFFFF_3000` | 读接收字符 |
| UART TX FIFO | `0xFFFF_3004` | 写发送字符 |
| UART 状态 | `0xFFFF_3008` | 读 FIFO 状态 |
| UART 控制 | `0xFFFF_300C` | 写初始化/控制 |
| 计时器低 32 位 | `0xFFFF_4000` | 只读 |
| 计时器高 32 位 | `0xFFFF_4008` | 只读 |

I/O 空间是最高 64 KiB，即 `0xFFFF_0000`～`0xFFFF_FFFF`；其余地址属于主存
空间。EGO1 的数码管位选和段选均为高电平有效。

### B 线门禁

| 阶段 | 验证要求 | 通过后得到的状态 |
| --- | --- | --- |
| B1 C_TEST 程序 | 在课程比特流上依次验证测试 0～2 | 软件侧 I/O 契约成立 |
| B2 AXI 主存 | Cache 关闭时通过 AXI Trace | 总线控制器、桥和主存成立 |
| B3 Cache | 启用 ICache/DCache 后再次通过 AXI Trace | 缓存路径成立 |
| B4 外设 | 五个必需外设定向仿真/下板，C_TEST 0～2 通过 | 完整单周期 SoC |

## 汇合线：流水线 SoC

只有 A4 和 B4 都完成后才进入汇合：

1. 用通过 Basic Trace 的流水线 `cpu_core` 替换已验证单周期 SoC 中的单周期内核。
2. 适配流水线暂停与 SoC 的取指、数据、Cache/AXI 返回握手；等待期间不得重复提交、
   丢失请求或让错误路径产生可见副作用。
3. 重新连接流水线 WB 和 MEM 提交点的 Trace 调试信号。
4. 让流水线 SoC 通过 AXI Trace。
5. 在流水线 SoC 上重新运行 C_TEST。
6. 在板上运行 CoreMark 或 LLAMA2，并在此基础上做频率、访存或运算优化。

对当前 miniRV + EGO1 配置，必做性能程序选为 CoreMark。LLAMA2 需要 Minisys 的
DDR/MIG 路径，是当前 EGO1 主线完成后的扩展，不应阻塞 CoreMark 主线。

## 频率、实现和板级门禁

- 模板默认 SoC 时钟为 50 MHz。
- 单周期 SoC 不得低于 25 MHz。
- 流水线 SoC 不得低于 50 MHz。
- 下板检查时不得有时序违例。
- 修改时钟后，要同步修改 CoreMark 等程序中的频率常量，否则计时结果无效。
- 报告中的时序、资源、功耗数据必须来自综合和实现完成后的结果。
- 自动化验证由仓库完成；实际烧录和板上现象由用户观察，未运行时不能声称已通过。

## 最终交付物

课程最终提交不是三个产品，而是报告加两套 SoC 源码：

```text
学号_姓名_comp2012/
├── 学号_姓名.pdf
├── single_cycle/   # 单周期 SoC 的 Verilog、最终实验 1 asm/coe
└── pipeline/       # 流水线 SoC 的 Verilog、最终实验 1 asm/coe
```

两套源码都必须能运行 Trace，并能下板运行实验 1 的最终汇编程序。只提交源码，不提交
Vivado 工程；最终 ZIP 不得超过 100 MB。报告还要给出单周期和流水线设计的实现后
时序、资源使用和功耗对比。

## 本仓库的建议执行顺序

课程安排允许 A、B 并行；单人仓库按以下门禁顺序可以减少交叉回归：

1. 保持 `lab1-complete` 不变，从它创建 `projects/pipeline/`。
2. 完成 A1～A4，冻结一个“流水线 CPU / Basic Trace”里程碑。
3. 在 `projects/single_cycle/` 完成 B1～B4，冻结“单周期 SoC / AXI Trace”里程碑。
4. 将流水线内核接入已验证 SoC，完成流水线 SoC 的 AXI Trace、C_TEST 和 CoreMark。
5. 对两套最终 SoC 分别运行实现、时序和导出验证。

若先做 B 再做 A，也不违反要求；关键约束是两个产品独立存在、各自中间门禁可复现，
并且在 A4/B4 之前不进入汇合调试。

## 快照时的已知前置缺口与状态

- `projects/pipeline/`、独立 lint 基线和双产品 Basic Trace 入口已经建立；当前
  pipeline 仍是 `lab1-complete` 的原样副本，尚未进入流水线 RTL 实现。
- 当前根构建已能分别验证两套产品的 Basic Trace。AXI SoC 接入后仍需依据实际
  编译拓扑增加 AXI 验证入口，不能把当前 Basic Trace 结果当作 AXI Trace 证据。
- 仓库中还没有 ICache/DCache 源码，需要在 B 线开始前确认来源和接口兼容性。
- 本地 `materials/lab2/c_test_rv_stu.tar.gz` 已按 Manifest 哈希验证；六套程序均已
  导入 `programs/c_test/`。测试 0～2 的 TODO 尚未实现，测试 3 和测试 5 仅保留
  原始基线，等待 Minisys/DDR 扩展门禁。

## 课程契约索引

- [Lab 2-A 总体要求](instruction-site/docs/lab2-A/0-overview.md)
- [Lab 2-A 实验步骤](instruction-site/docs/lab2-A/7-step.md)
- [Lab 2-A 理想流水线](instruction-site/docs/lab2-A/2-idealpl.md)
- [Lab 2-A 数据冒险处理](instruction-site/docs/lab2-A/4-handleDH.md)
- [Lab 2-A 控制冒险处理](instruction-site/docs/lab2-A/5-handleCH.md)
- [Lab 2-A 取指与暂停/清空](instruction-site/docs/lab2-A/6-ifetch.md)
- [Lab 2-B 总体要求](instruction-site/docs/lab2-B/0-overview.md)
- [Lab 2-B 实验步骤](instruction-site/docs/lab2-B/3-step.md)
- [Lab 2-B SoC/AXI/Cache 接口](instruction-site/docs/lab2-B/1-sysbus.md)
- [Lab 2-B I/O 地址与外设](instruction-site/docs/lab2-B/2-ioitf.md)
- [Lab 2-B AXI 与 Cache 集成](instruction-site/docs/lab2-B/4-bus_impl.md)
- [Lab 2-B C_TEST](instruction-site/docs/lab2-B/5-ioupg.md)
- [最终提交要求](instruction-site/docs/home/submit.md)
- [固定 Trace 驱动](../cdp-tests/csrc/dut.h)
