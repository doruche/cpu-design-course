# 单周期 SoC Stage 4：C_TEST 软件与自动化联调任务书

## 状态

- 状态：Defined（2026-07-27；实现未开始）
- 父任务：[单周期 SoC 开发](single-cycle-soc.md)
- 基线提交：`bb7e97d`
- 产品配置：`single-soc-cache`
- 课程程序：`programs/c_test/0_uart_test`、`1_formatIO_test`、`2_sort_test`
- 物理软件 oracle：课程提供的 miniRV + EGO1 SoC bitstream

本文只解析和冻结 Stage 4。C_TEST 源码、构建入口、系统 testbench、产品 RTL、XCI、
COE 和 Vivado 工程均未在本检查点修改；未运行 C_TEST 构建、仿真或实际板测。

## 重新划界

原父任务把 C_TEST 软件联调、自己的单周期 SoC 下板和后续 Vivado 收尾放在相邻阶段，
但自己的 SoC 下板必然依赖 implementation 和 bitstream。为避免用尚未生成的物理产品
关闭 Stage 4，本阶段重新限定为：

1. 完成并验证 miniRV C_TEST 0～2；
2. 产生含义明确、可追溯的 ELF、反汇编、仿真镜像、COE 和 UART 下载包；
3. 在 `single-soc-cache` 的 CPU-driven RTL System 测试中验证程序与五类 MMIO；
4. 由用户使用课程提供的已知良好 SoC bitstream 验证 C_TEST 软件和交互步骤。

Stage 4 不修改或生成自己的产品 bitstream，也不声明自己的 SoC 已经下板通过。产品
BRAM/IP、时钟复位、implementation、bitstream、实现后时序和自己的 SoC 实板观察均
不属于本文；这里只记录它们不能被 Stage 4 自动化或课程 bitstream 结果替代，不展开
下一阶段方案。

## 课程合同

固定版本指导书对本阶段给出以下有效要求：

- C_TEST 0～2 各有五处 TODO：测试 0 验证 UART 外设读写，测试 1 验证
  `printf`/`scanf`，测试 2 验证递归和 `malloc`；
- 编译产物包括反汇编、COE 和用于课程下载器的 BIN；
- 课程先提供 miniRV + EGO1 SoC bitstream，用户通过 115200 baud、无流控的串口下载
  BIN 并交互，以隔离验证 C_TEST 软件；
- 最终课程产品仍要求在 SoC 上下板运行 I/O 测试，并覆盖 switch、LED、数码管、UART
  和 timer；课程 bitstream 的软件 PASS 不是自己的产品 PASS。

课程行为以 `materials/instruction-site/` 的固定版本为准。`materials/lab2/` 下的归档、
bitstream 和转换脚本是带哈希的本地输入，不是第二份课程规范。

## 所有权

| 关注点 | 所有者 | Stage 4 约束 |
| --- | --- | --- |
| 课程 C_TEST 行为 | 固定指导书与原始归档 | 不修改 submodule 或忽略目录中的归档 |
| 可维护 C_TEST 源码 | `programs/c_test/0_*`～`2_*` | 只在工作副本完成 TODO 和明确的软件缺陷 |
| 学号身份 | 用户提供的必需输入 | 不猜测、不提交占位符作为通过产物 |
| 公开程序构建 CLI | 根 `Justfile` 与 `scripts/` | 不恢复根 Make CLI；内部后端不得成为第二公开入口 |
| 生成程序产物 | 忽略的 `.cache/programs/c_test/` | 不在源码目录生成 ELF、BIN、COE 或临时 linker script |
| RTL System oracle | `tests/` 下的仓库 testbench | CPU 发起 MMIO；testbench 只驱动/观察板级边界 |
| 产品 RTL/MMIO 合同 | `projects/single_cycle/src/rtl/` | 默认只读；若程序暴露硬件缺陷，先形成失败用例再重新定界 |
| 课程 bitstream 板测 | 用户 | agent 准备镜像、步骤和期望；用户烧录、交互并报告现象 |

## C_TEST 功能合同

### C_TEST 0：UART 与基础 MMIO

- 清空 UART RX/TX FIFO；发送前等待 TX 非满，接收前等待 RX 非空；
- 输出固定标题和 `Hello World!`，接收并回显字符；
- 将字符 ASCII 值写入 LED 与八位数码管；
- switch 非零时继续交互，switch 为零时输出 `Test ended.` 并结束。

### C_TEST 1：格式化输入输出

- 复用相同 UART 寄存器合同，完成输入缓冲；
- 正确输出十进制、十六进制、字符、字符串和浮点格式；
- 读取 `int + char + string` 并回显；
- 负整数令 LED0 点亮，数码管显示绝对值；字符串为 `end` 时结束。

### C_TEST 2：递归、heap 与 timer

- 读取八个整数，递归 quicksort 后按非降序输出；
- 分配用户指定长度的动态数组，生成、排序、输出并释放；
- timer 软件读取必须服从当前非原子双端口合同：执行 high-low-high，并在两次 high
  不一致时重试；
- 计时输出按 50 MHz 默认 CPU 时钟换算，修改频率时必须由同一显式输入同步更新。

三个测试均不得把串口终端人工观察当作唯一 oracle。格式化输出、解析、排序、heap
边界和 timer 读取还需要仓库自有的确定性检查。

## 程序与镜像合同

当前课程脚本把 `.bin` 同时当作名称普通的“二进制”和课程 UART 下载协议包，但后者
实际包含 word-count 头；现有 RTL System 测试读取的则是无头原始内存字节。Stage 4
必须为不同消费者使用不同产物名：

| 产物 | 消费者 | 合同 |
| --- | --- | --- |
| `<test>.elf` | section/ABI 审计 | RV32IM、ILP32、reset PC `0x00000000` |
| `<test>.dump` | 人工和失败定位 | 与同一 ELF 一次构建生成 |
| `<test>.raw.bin` | RTL behavioral memory | 无协议头，按物理地址展开的原始字节 |
| `<test>.coe` | 后续 Vivado BRAM 消费者 | 32-bit word 初始化，不在 Stage 4 绑定 XCI |
| `<test>.uart.bin` | 课程 bitstream 下载器 | word-count 头加与 COE 一致的 payload |
| `<test>.manifest` | 证据与交接 | 源提交、工具版本、section 范围、大小及全部哈希 |

禁止通过去掉头后“碰巧可运行”来推断 COE、raw image 和 UART payload 等价；构建门禁
必须结构化解析并逐 word 比较三者的公共 payload。

课程 linker 当前声明三个连续 50 KiB 区域：text 从 `0x00000000` 开始，data/rodata
从 `0x0000C800` 开始，heap/stack 范围从 `0x00019000` 到 `0x00025800`。因此：

- Stage 4 的 behavioral System memory 必须显式覆盖至少 `0x00025800` 字节；
- 当前固定 Trace `bram_axi` 默认 32 KiB，不能直接作为 C_TEST 容量真相；
- 当前产品 XCI 为 12,800 个 32-bit word（50 KiB）且仍绑定 `lw.coe`，与 C_TEST
  linker 不相容；该事实记录为后续产品交接，不在 Stage 4 修改 XCI；
- linker、System memory 与最终产品 memory 的有效范围在各自阶段必须显式检查，不能
  由 `defines.vh` 中的地址常量替代实际容量证明。

## 当前已知软件缺口

除指导书标注的十五处 TODO 外，实施前已确认以下工作副本问题：

- 测试 1/2 的 `vscanf` 在判断 `input_ptr == 0` 前先解引用该指针；
- 测试 2 的 `delay_ms` 使用未定义的 `CLOCKS_PER_SEC`，头文件定义的是
  `CLKS_PER_SEC`；
- 测试 2 当前以 low-high 顺序读取 timer，不满足 Stage 3 已关闭的 rollover 合同；
- `programs/c_test/Makefile` 和 README 仍把子目录 Make wrapper 写成用户入口，尚未接入
  当前唯一公开 Just CLI；
- 课程脚本在临时目录生成启动代码、linker script 和多种产物，新的仓库入口需要保留
  其可复现关系而不能直接在 canonical source 旁运行。

这些是 Stage 4 软件/工作流范围，不构成修改指导书或原始归档的理由。

## 验证分层

| 层级 | 自动化责任 | 证明 | 不证明 |
| --- | --- | --- | --- |
| Source | TODO/占位符、静态软件检查 | 工作源码完整且不存在已知 UB/拼写缺陷 | 目标 ABI 或硬件行为 |
| Program build | ELF、section、镜像和 manifest | RV32IM 构建可复现，所有产物同源且容量合法 | CPU/MMIO 执行 |
| Software | 格式化、解析、排序、heap/timer helper 定向测试 | C 逻辑及边界行为 | 真实 UART 帧或 Cache/AXI |
| System | CPU-driven `single-soc-cache` | 程序经过 CPU、双 Cache、AXI、fabric、memory 和 MMIO | PLL、XCI、约束、物理 I/O |
| Course-board oracle | 用户使用课程 bitstream | 程序下载协议和 C_TEST 交互在已知良好 SoC 上成立 | 自己的 RTL、时序或 bitstream |

System 测试可以使用显式的仿真专用 UART 时间缩放来控制运行时间，但不得改变 UART
寄存器、FIFO 或软件轮询语义；现有 50 MHz/115200 完整 8N1 unit 回归必须保留。System
testbench 不得直接写 UART FIFO、LED、数码管或 timer 内部寄存器来替代 CPU 指令。

## 预定公开入口

Stage 4 实现后只增加以下根 Just CLI 入口；具体后端仍由 `scripts/build.sh` 路由，不把
`programs/c_test/Makefile` 或课程 `compile.sh` 暴露为第二套用户 CLI：

```text
just program c-test-0|c-test-1|c-test-2
just system  c-test-0|c-test-1|c-test-2
just gate    single-stage4-auto
```

`program` 只构建并审计程序产物，`system` 运行对应的 CPU-driven RTL suite，
`single-stage4-auto` 汇总全部自动门禁但不包含用户板测。不存在用自动 gate 直接把 Stage 4
标记 Completed 的入口；S4-U 证据必须单独记录。

## 实施检查点

### S4-0：合同冻结（本检查点）

- 冻结重新划界、所有权、镜像类型、memory 范围、验证分层和停止条件；
- 记录十五处 TODO、非 TODO 软件缺陷、当前 XCI/behavioral memory 容量差异；
- 不修改程序、构建、RTL、Vivado 工程或板级材料。

状态：Completed（2026-07-27，docs-only）。

### S4-1：程序构建与失败基线

- 先为 UART helper、格式化输入、timer rollover、quicksort 和 heap 边界建立失败测试；
- 将 C_TEST 0～2 构建接入公开 Just CLI，产物只进入 `.cache/programs/c_test/`；
- 结构化验证 ELF sections、150 KiB address contract、raw/COE/UART payload 和 manifest；
- 要求用户提供学号输入；缺失身份时允许开发构建，但不得生成候选板测/关闭产物。

默认写集：`Justfile`、`scripts/`、`tests/`、`programs/c_test/README.md` 和必要的测试
fixture。此检查点不修改 C_TEST TODO 或产品 RTL。

### S4-2：完成 C_TEST 0～2

- 在失败测试存在后完成 UART、`printf`/`scanf`、timer 和身份内容；
- 修复已确认的空指针、时钟宏和 timer rollover 问题；
- 使三个程序在 RV32IM/ILP32 下无占位符地通过构建与软件定向测试；
- 不顺带处理 DDR、CoreMark、LLAMA2 或课程归档中的其他源码。

默认写集：`programs/c_test/0_uart_test/`、`1_formatIO_test/`、`2_sort_test/` 及 S4-1
测试。若需要改变 CPU ISA 或 MMIO 当前合同，立即停止并重新定界。

### S4-3：CPU-driven C_TEST System

- 为三个 C_TEST 分别提供确定的 UART/switch 输入脚本和 transcript oracle；
- 测试 0 检查 UART 回显、ASCII LED/数码管和 switch 结束；
- 测试 1 检查全部格式、输入回显、符号 LED 和绝对值数码管；
- 测试 2 检查两轮非降序输出、`malloc/free` 完成和 timer 关系；
- 保持普通 memory Cache refill、MMIO uncached 单拍及五类外设既有断言；
- 三个 suite 设置明确超时和 PASS/FAIL 摘要，不以波形人工浏览作为通过条件。

默认写集：`tests/`、`scripts/`、`Justfile` 和必要的 simulation-only adapter。产品 RTL
默认只读；若失败指向硬件，先保存最小失败用例并请求重新定界。

### S4-U：课程 bitstream 用户验证

agent 负责准备并记录：

- 源提交、toolchain、课程 bitstream SHA-256 和三个 `<test>.uart.bin` SHA-256；
- 115200 baud、无流控、reset、二进制发送步骤；
- 每个测试的输入序列、期望 transcript、LED/数码管/switch 观察清单；
- 可直接填写的 PASS/FAIL 记录。

用户负责连接 EGO1、使用 Hardware Manager 下载课程 bitstream、通过串口发送程序并
反馈实际现象。若 S4-1～S4-3 已通过而本检查点未运行，Stage 4 状态只能是
`Awaiting User Board Evidence`，不能标记 Completed。

## 自动关闭门禁

进入 S4-U 前至少要求：

- `just --fmt --check`、`just doctor`、shell syntax 和全部程序配置解析通过；
- C_TEST 0～2 无 TODO/身份占位符，三套 build/software/System 测试通过；
- ELF、raw、COE、UART package 和 manifest 的结构/哈希关系通过；
- 当前 Unit、Integration、六配置 lint、六配置完整 Trace 和 `soc-smoke` 保持通过；
- `xmllint --noout projects/single_cycle/miniRV.xpr` 与 `git diff --check` 通过；
- 两个 submodule 保持固定且未修改；
- 报告 FPGA implementation、自己的 bitstream 和自己的 SoC 实板结果为 Not Run。

完整 Stage 4 关闭还要求 S4-U 三个程序的用户记录均为 PASS。课程 bitstream 失败时，
先按程序构建、UART package、串口配置和输入序列定位；不得把失败静默归因于自己的
产品 RTL。

## 停止条件

出现以下任一情况立即停止当前检查点并请求重新定界：

- 需要修改指导书、Trace submodule 或忽略的课程归档/bitstream；
- 需要改变 CPU ISA、两份设计 CSV、Trace public 信号或
  `miniRV_SoC.U_cpu.U_core` 层次；
- 需要改变 Stage 3 已关闭的 MMIO 地址、UART 寄存器/FIFO 或 Cache/AXI 语义；
- 需要修改产品 XCI/COE 绑定、时钟/复位、XDC，或运行 implementation/bitstream；
- 需要以自己的 SoC 实板结果作为当前检查点输入；
- 需要进入 DDR、CoreMark、LLAMA2、流水线产品或性能优化；
- 需要 testbench 绕过 CPU 直接操纵外设内部状态才能令 C_TEST 通过；
- 缺失用户学号却准备生成候选板测或关闭产物。

## 完成后的交接

Stage 4 只交付已验证的 C_TEST 源码、可复现程序产物合同、三个 CPU-driven System
suite，以及课程 bitstream 的用户软件验证记录。任何后续消费者必须显式选择 COE 和
物理 memory 容量，并重新证明实现后时序及自己的 SoC 板级行为；本文不预先设计或
声明这些结果。
