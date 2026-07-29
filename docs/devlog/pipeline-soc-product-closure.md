# 流水线 SoC 产品闭环任务书

## 状态

- 状态：Active（PC0 已完成；PC1～PC6 与 PC-U Pending，不得自动进入）
- 建立日期：2026-07-30
- 基线提交：`4581d8dd6ffc792912429f8d176e266070369193`
- 产品：`projects/pipeline/`
- 主配置：`pipeline-soc-cache`
- 目标板：EGO1（XC7A35TCSG324-1）
- 时钟目标：50 MHz
- 性质：流水线 SoC 工程与物理产品闭环；不是官方验收策略对齐任务

本文接手 Linux 环境已经完成的流水线 CPU、SoC RTL、Trace 和 CoreMark 历史仿真，
把 `projects/pipeline/` 关闭为可重复综合、实现、生成候选 bitstream 并由用户在 EGO1
上验证的物理产品。

队友未具备 Vivado 环境，因此当前 pipeline 交付边界是 Linux 下可验证的 RTL 与仿真，
而不是一个已经接通但尚未运行的 Vivado 产品。PC1 起必须以 canonical XPR/XCI/XDC/COE
和 Vivado 2023.2 的实际结果建立物理证据，不能从 Trace、Icarus 仿真或单周期产品结果
推导 pipeline synthesis、timing、bitstream 或板级结论。

## 与后续官方验收对齐的边界

本任务只关闭工程能力和产品证据。以下内容由后续独立的官方验收对齐任务书决定，本任务
不得自动开始或夹带实施：

- 是否把自有 `soc_interconnect` 迁移为 AXI Crossbar IP；
- 是否把自有 switch/LED/数码管/timer 外设迁移为 AXI GPIO 与 Protocol Converter；
- 是否把自有 `uart_peripheral` 迁移为 AXI Uartlite；
- 指导书中的具体 IP 拓扑属于硬验收合同、参考实现还是允许等价实现的策略判断；
- 实验报告模板、双产品截图与对比、最终实验一汇编/COE、平铺提交目录和 ZIP 封版；
- 最终演示流程、提交系统限制和课程验收清单逐项签收。

后续任务书必须区分官方概览中的功能要求、详细章节的参考实现步骤、提交要求和教师现场
验收口径；不得因为本任务的自有 RTL 通过自动化就写成已经对齐官方实现策略。

## 进入基线与现有证据

### 已有能力

- IF/ID、ID/EX、EX/MEM、MEM/WB 四组段寄存器和五级顺序提交核已经实现；
- 静态预测不跳转、EX 分支解析、load-use stall、EX/MEM 与 MEM/WB 前递、WB 到 ID
  旁路、乘除法等待和无界延迟访存握手已经实现；
- pipeline 五个稳定配置的 lint 与各 45 项 Trace 已通过；
- `just unit pipeline-control` 已覆盖 fetch/flush、skid buffer、load-use、EX hold、
  mul/div completion、memory completion 和错误路径副作用组合；
- Cache、AXI master、自有 interconnect、主存/MMIO 路由和五类外设已通过仓库 unit、
  integration 与 product-topology 仿真；
- `just system coremark` 已有 feature branch 上的一次迭代历史 PASS 和性能记录，但
  merge 后宿主环境因 soft-float/libgcc ABI 不匹配未重现该结果。

上述证据证明流水线 RTL 与仿真产品已形成，不证明 canonical pipeline Vivado 工程、
50 MHz implementation、bitstream 或 EGO1 行为。

### 当前已知缺口

1. `projects/pipeline/miniRV.xpr` 的 Design Sources 仍停留在旧工程，缺少 Cache、
   `axi_master`、`soc_interconnect`、外设 RTL 和 `bram_axi` block source，同时保留不属于
   当前物理 SoC 路径的 IROM/DRAM fileset。
2. `bram_axi.xci` 指向不存在的 `../../../coe/stage5-placeholder.coe`；pipeline 产品下
   没有 canonical placeholder，也没有显式候选 COE 选择闭环。
3. pipeline XPR 没有 `stage5.xdc`；主 run 仍记录 Vivado 2018 flow，不能作为当前
   Vivado 2023.2 产品证据。
4. pipeline `build.tcl` 没有版本钉、candidate COE 回读、BRAM 容量检查、结构化 facts、
   setup/hold、未约束路径、DRC、methodology 和 CDC 证据输出。
5. `scripts/vivado.sh`、candidate 入口和 evidence collector 只对 `single_cycle` 关闭；
   pipeline 尚不能显式构建、审计和区分 C_TEST/CoreMark 候选。
6. `system_c_test` 硬编码 `single-soc-cache`，C_TEST 0～2 当前不构成 pipeline SoC 证据。
7. merge 后固定工具链的 CoreMark RTL system suite 尚未在当前 `main` 重现；当前宿主
   `doctor` 只检查命令存在，没有证明 RV32IM/ILP32 与运行库 ABI 可链接。
8. pipeline synthesis、implementation、50 MHz 时序、bitstream 和 EGO1 板测全部为
   **Not Run**；`artifacts/pipeline/` 也没有正式报告。

## 产品关闭目标

本任务关闭时必须同时满足：

1. canonical pipeline XPR 精确消费当前 product SoC RTL、Clock Wizard、AXI BRAM、
   XDC 和显式候选 COE，不依赖 Windows staging 手工修改；
2. pipeline C_TEST 0～2 在 `pipeline-soc-cache` 的 CPU-driven system simulation 中通过；
3. 当前 `main` 在固定、可审计的 RV32IM/ILP32 工具链中通过 CoreMark CRC system suite；
4. pipeline 五配置 lint、各 45 项 Trace、`pipeline-control` 和受影响的共享 unit/
   integration suites 保持通过；
5. clean 源提交使用 Vivado 2023.2 完成 synthesis 和 implementation；
6. 50 MHz 下 setup/hold 无违例、未约束路径为零，阻塞性 DRC 和 critical warning 为零；
7. C_TEST 0～2 与 CoreMark 四个候选均可由公开入口显式选择，且 bitstream、COE、program
   manifest、源提交和 Vivado facts 一一对应；
8. 用户在 EGO1 上使用自己的 pipeline bitstream 完成 C_TEST 0～2 和 CoreMark 验证；
9. pipeline timing、utilization、power 和构建元数据以小型可审计文本归档到
   `artifacts/pipeline/`，bitstream 与原始 run 目录仍保持忽略；
10. 更新产品状态和 devlog，创建经用户确认的 pipeline 物理产品里程碑 tag，并明确把
    官方 IP/报告/提交对齐交给下一份任务书。

## 必须保持的不变量

### CPU、Trace 与设计合同

- 保持 reset PC `0x00000000`、五级划分、四组段寄存器和按程序顺序提交；
- 保持 `miniRV_SoC.U_cpu.U_core` 层次和全部 `/* verilator public */` 信号；
- `debug_wb_*` 继续表示架构提交，`debug_mem_*` 继续表示实际生效的存储写；
- 保持静态预测不跳转、冒险/前递、单在途 IF/MEM 请求、mul/div completion 和 flush
  priority；
- `design/pipeline/*.csv` 是流水线语义合同，默认只读；若物理修复要求改变语义，停止
  当前检查点，不得同时修改合同和实现制造一致。

### SoC 与产品所有权

- `projects/pipeline/` 是 pipeline RTL、XPR、XCI、XDC、COE 和 Tcl 的唯一 canonical
  owner；Windows staging 是可删除的派生树；
- 不从 `projects/single_cycle/` 运行时 include、symlink 或生成复制 RTL；允许对照已关闭
  Stage 5 的工程能力，但每项迁移都必须在 pipeline owner 内独立审计；
- 保持 CPU 到 Cache、Cache 到 AXI、AXI/MMIO 地址和五外设寄存器语义；
- 保持 EGO1 100 MHz 输入、50 MHz 产品时钟、低有效板级 reset、115200 baud、8N1、
  无流控；
- Clock Wizard 与 AXI BRAM 继续作为本任务的 Vendor IP 边界；其他 IP 策略不在本任务
  改变；
- 不修改 `cdp-tests/` 或 `materials/instruction-site/` 两个 submodule，不在
  `cdp-tests/mySoC/` author RTL。

### 证据边界

- lint/Trace/System PASS 不证明 Vivado；synthesis 不证明 implementation；生成 `.bit`
  不证明时序、程序 provenance 或板级行为；
- 单周期 Stage 5 证据只能作为流程和物理合同参考，不能替代 pipeline 结果；
- feature branch CoreMark 数据只保留为历史性能记录，不能替代当前 clean source 证据；
- 用户板测必须记录候选 bitstream hash 和实际现象，不能用另一候选或课程 bitstream PASS
  替代。

## 明确非目标

- 不迁移到 AXI Crossbar、AXI GPIO、Protocol Converter 或 AXI Uartlite；
- 不改变 ISA、流水线级数、分支策略、Cache 参数、AXI 仲裁策略或 MMIO ABI；
- 不继续 radix-4 multiplier、组合访存路径、Cache 调参或其他性能优化；
- 不通过降频到 50 MHz 以下、放宽 timing/DRC 判定或修改 CoreMark 时钟常量掩盖问题；
- 不实现 UART bootloader、运行时程序下载协议、异常、中断、DDR 或 LLAMA2；
- 不修改单周期产品 RTL、XPR/XCI/XDC 或已关闭的单周期证据；共享脚本若必须扩展，须保持
  现有单周期入口和语义兼容；
- 不创建最终报告 PDF、最终演示汇编、平铺提交目录或 ZIP；
- 不创建 `lab2-complete` 等课程最终里程碑 tag。

## 候选程序与 bitstream 合同

本任务至少维护四个显式 pipeline 候选：

| 候选 | 程序 owner | 产品用途 |
| --- | --- | --- |
| `c-test-0` | `programs/c_test/0_uart_test/` | UART、switch、LED、数码管和 reset bring-up |
| `c-test-1` | `programs/c_test/1_formatIO_test/` | 格式化 I/O、输入回显和外设显示 |
| `c-test-2` | `programs/c_test/2_sort_test/` | 递归、heap、timer 和排序 |
| `coremark` | `programs/c_test/4_coremark/` | pipeline SoC 正确性与十秒板上性能 |

公开 CLI 必须同时显式表达 pipeline 产品、candidate 和 action，且保持现有单周期 candidate
入口兼容。具体命令拼写在 PC1 的 CLI/owner 审计中冻结；不得通过当前工作目录、最近一次
program build、XCI 中的旧路径或 Windows GUI 隐式选择程序。

每个 candidate 必须记录：

- clean source commit、Vivado 2023.2、part 和 50 MHz 时钟合同；
- program manifest、ELF/BIN/COE hash 和实际由 XCI/Tcl 消费的 COE；
- BRAM width/depth 与 candidate image 边界；
- implementation timing、unconstrained path、DRC、methodology 和 CDC 摘要；
- bitstream SHA-256 和 candidate selection facts。

## 责任边界

### Agent 负责

- canonical pipeline 工程、构建入口、自动失败合同和修复；
- 当前工具链 ABI 探针、pipeline C_TEST system suite 和 CoreMark RTL 重现；
- WSL 到 Windows 的可重复 staging、Vivado batch synthesis/implementation/bitstream；
- timing、DRC、methodology、CDC、资源、功耗与 provenance 的机器判定和归档；
- candidate 清单、hash、串口设置、输入步骤和期望现象；
- 失败后的最小复现、回归补充和重新生成候选。

### 用户负责

- 连接 EGO1、JTAG 和 UART，确认串口设备；
- 烧录 agent 指定 hash 的 bitstream；
- 按清单操作 reset、switch、串口输入并观察 LED/数码管；
- 保存 C_TEST/CoreMark 实际输出，报告候选 hash、步骤和 PASS/FAIL；
- CoreMark 使用规定运行时长，记录有效迭代、错误计数、CRC 和分数。

用户不负责修改 Windows staging、XCI、RTL 或时序约束，也不负责判断自动门禁是否足够。

## 执行规则

1. 严格按 PC0、PC1、PC2、PC3、PC4、PC5、PC-U、PC6 顺序执行；前一项未关闭不得
   自动进入下一项。
2. 每个实现检查点形成独立、聚焦提交。失败合同、Vivado 工程修复、System 软件证明、
   clean physical evidence 和最终文档关闭不得混在一个提交。
3. 每个 checkpoint 的默认 write set 是硬边界。需要扩展时，先在本文 Write Set 扩展
   记录中说明文件、owner、原因、外部合同和新增门禁，并获得用户确认。
4. 测试必须先在未修产品上表达稳定失败，再修改对应 owner。不能用文本匹配替代可结构化
   解析的 XPR/XCI/XML/Tcl/facts 合同。
5. 任一 failure 若指向 pipeline CPU/Cache/AXI/MMIO 语义错误，保存最小失败证据并停止；
   不在物理工程或测试 checkpoint 夹带 RTL correctness fix。
6. Vivado 交互排障可由用户协助，但修复必须回到 WSL canonical owner 并通过 batch 重现；
   不编辑 Windows staging。
7. PC0 完成后必须停止。本任务书的存在不构成进入 PC1 的授权。

## 实施检查点

### PC0：任务书与范围冻结

状态：Completed（2026-07-30，docs-only；未进入 PC1）。

默认 write set：

- `docs/devlog/pipeline-soc-product-closure.md`
- `docs/devlog/README.md`
- `README.md`

工作：

- 记录 Linux RTL/仿真与 Vivado 物理产品之间的当前证据边界；
- 冻结产品目标、非目标、候选、责任、检查点、默认写集和停止条件；
- 把官方 IP、报告和提交对齐明确延期到后续独立任务书；
- 不修改 RTL、测试、构建脚本、Vivado 工程或生成物。

验证门禁：

```bash
just --fmt --check
just doctor
git diff --check
git status --short
```

PC0 只证明任务书和索引一致，不构成 pipeline C_TEST、CoreMark、Vivado 或板级证据。

### PC1：失败基线、owner 审计与机器合同

状态：Pending。

默认 write set：

- `tests/stage5/`
- `scripts/stage5_contract.py`
- `scripts/doctor.sh` 与其测试，仅限 RV32IM/ILP32 链接探针
- `scripts/build.sh`、`Justfile`，仅限暴露检查入口或 candidate CLI dry-run
- 本任务书执行记录

产品 RTL、XPR/XCI/XDC/COE、Tcl 和 C_TEST 源码在 PC1 只读。

工作：

- 结构化审计 pipeline XPR 的 Design Sources、BlockSrcs、constraints、part、run flow 和
  stale legacy fileset；
- 结构化审计 `bram_axi.xci` 的 width、depth、COE 路径和 candidate override 能力；
- 冻结 pipeline candidate CLI 的 product/candidate/action 语义，同时保持 single-cycle
  入口兼容；
- 扩展 Stage 5 contract，使 single-cycle 既有正例继续通过，pipeline 当前缺口稳定失败；
- 为 RV32IM/ILP32 freestanding 程序增加实际 compile/link runtime probe，区分“命令存在”
  与“ABI 可用”；
- 记录 `system_c_test` 缺少 pipeline route 的失败基线；
- 冻结 PC2 的 XPR source inventory、placeholder COE、stage5 XDC 和 evidence facts 目标。

验证门禁：

```bash
just unit stage5-contract
just doctor
just --fmt --check
git diff --check
```

关闭 PC1 时允许 pipeline contract 以预期失败结束，但 single-cycle Stage 5 contract、现有
公开入口和无关 doctor 检查必须保持通过。失败项和预期修复 owner 必须逐项写入本文。

停止条件：

- 无法从 canonical XPR/XCI/Tcl 判断实际 source、COE、part 或 run owner；
- candidate API 需要破坏现有 single-cycle 入口语义；
- ABI 修复要求替换课程程序、修改 CoreMark 算法或在宿主机引入不可固定的全局环境。

### PC2：Canonical Vivado 产品路径修复

状态：Pending。

默认 write set：

- `projects/pipeline/miniRV.xpr`
- `projects/pipeline/src/rtl/ip/bram_axi/bram_axi.xci`
- `projects/pipeline/src/coe/` 下必要的 placeholder
- `projects/pipeline/src/xdc/` 下必要的 Stage 5 约束
- `projects/pipeline/scripts/build.tcl`
- `scripts/vivado.sh`
- `scripts/collect_vivado_evidence.py`
- `scripts/check_vivado_result.py`
- `scripts/build.sh`、`Justfile`
- PC1 tests 与本任务书执行记录

`projects/pipeline/src/rtl/*.v` 默认只读。若 canonical XPR 接通后暴露产品 RTL 缺陷，停止
PC2 并保存 Vivado/RTL 最小失败证据。

工作：

- 使 XPR Design Sources 与当前 physical product SoC 精确一致，删除确认不属于产品的
  stale IROM/DRAM 工程项，加入 AXI BRAM 和全部必需 product RTL；
- 加入 pipeline `stage5.xdc`，保持 Clock Wizard、reset、CDC 和 EGO1 pin 合同；
- 使用 product-local placeholder COE，禁止不存在路径和隐式 `lw.coe`；
- 把 Vivado 2023.2、part、BRAM 容量、candidate COE 回读和 build facts 移植为 pipeline
  owner 下的可审计能力；
- 扩展 staging、candidate 和 evidence collector 以支持 pipeline，禁止生成物污染；
- 先完成 dirty-source stage/synthesis 路径证明，不在 PC2 声明 clean implementation。

验证门禁：

```bash
just unit stage5-contract
just lint pipeline-soc-cache
just trace pipeline-soc-cache addi
just unit pipeline-control
just vivado pipeline stage
just vivado pipeline synth
xmllint --noout projects/pipeline/miniRV.xpr
git diff --check
```

停止条件：

- Vivado source inventory 需要修改 pipeline RTL 接口或 SoC 拓扑；
- pipeline 需要不同于现有 50 MHz/BRAM/clock-reset 的产品合同；
- 修复要求迁移到官方 AXI/GPIO/UART IP 拓扑；
- synthesis 暴露真实时序优化需求或功能错误，超出工程接通范围。

### PC3：Pipeline C_TEST 与固定工具链 System 证明

状态：Pending。

默认 write set：

- `scripts/build.sh`
- `Justfile`
- `scripts/doctor.sh` 与工具链环境定义
- `.devcontainer/`，仅限关闭可复现工具链缺口
- `tests/c_test/`、`tests/coremark/` 和必要的 transcript checker
- 本任务书执行记录

产品 RTL 与 C_TEST/CoreMark 功能源码默认只读。现有 `just system c-test-0|1|2` 的
single-cycle 含义必须保持兼容；新增 pipeline suite 必须显式命名产品或配置。

工作：

- 为 C_TEST 0～2 增加显式 `pipeline-soc-cache` system route；
- 保持 program image、manifest、memory range、UART transcript 和 peripheral oracle；
- 在固定工具链中通过 RV32IM/ILP32 ABI probe，并重现当前 `main` 的 CoreMark build；
- 运行 pipeline C_TEST 0～2 与 CoreMark CRC system suite；
- 任一失败先归类为软件、工具链、fixture、product fabric 或 pipeline RTL，不跨 owner
  直接修复。

验证门禁至少包括：

```bash
just unit c-test-software
just system pipeline-c-test-0
just system pipeline-c-test-1
just system pipeline-c-test-2
just system coremark
just unit pipeline-control
git diff --check
```

上述 pipeline suite 名称是本任务冻结的目标公开语义；若 PC1 选择等价且更符合现有 Just
模式的拼写，必须在进入 PC3 前同步本文并获得用户确认。

停止条件：

- C_TEST/CoreMark 失败要求修改 ISA、MMIO ABI 或课程程序预期；
- 只能通过放宽 transcript/CRC、memory bounds 或重复事务断言使测试通过；
- 固定环境仍不能提供一致的 RV32IM/ILP32 runtime，且需要新的外部工具链 authority。

### PC4：当前主线自动回归与 clean synthesis

状态：Pending。

默认 write set：本任务书执行记录。PC4 默认不修改源文件。

工作：

- 在 PC2/PC3 实现提交后的 clean `main` 上运行完整自动门禁；
- 确认 closure 纳入 pipeline C_TEST、CoreMark、pipeline-control、十配置 lint/Trace、共享
  unit/integration 和 XPR/XCI semantic checks；
- 从空 staging 对 clean source 执行 canonical pipeline synthesis；
- 记录 source commit、Vivado version、part、BRAM、clock 和 synth critical warning；
- 确认两个 submodule 未修改，canonical tree 无 Vivado 生成物污染。

验证门禁：

```bash
devcontainer exec --workspace-folder . just gate closure
just vivado pipeline synth
git status --short
git diff --check
```

若本机没有 `devcontainer` CLI，可使用同一 `.devcontainer` 镜像的等价非交互入口，但必须
记录镜像定义和命令，不能回退到已知 ABI 不匹配的宿主结果。

停止条件：

- closure 失败指向未授权的产品语义修改；
- clean synthesis 与 PC2 dirty-source 结果不一致；
- source commit、staging 内容或 Vivado version 不能一一对应。

### PC5：Clean implementation、四候选与正式工程证据

状态：Pending。

默认 write set：

- `artifacts/pipeline/` 下小型文本报告和 metadata
- `artifacts/README.md`，仅同步证据索引
- 本任务书执行记录

bitstream、完整日志、Vivado run 目录和 Windows staging 保持忽略，不提交 Git。

工作：

- 从同一 clean product source 分别构建 C_TEST 0～2 与 CoreMark candidate；
- 每个 candidate 独立完成 implementation 和 bitstream，验证实际 COE 与 selection facts；
- 50 MHz 下 setup/hold 无负 slack，unconstrained path 为零；
- DRC error、阻塞性 critical warning 为零；methodology/CDC 必须逐项机器判定或记录明确
  review disposition；
- 归档 pipeline timing、utilization、power 与 source/tool/program metadata；
- 形成 PC-U 清单：bitstream hash、COE hash、串口参数、输入步骤和期望现象。

验证门禁：

```bash
just unit stage5-contract
just gate closure
# 对四个显式 pipeline candidate 分别执行 canonical bitstream action
git diff --check
```

每个候选必须有独立 `check_vivado_result.py` PASS 和 SHA-256 清单。

停止条件：

- 50 MHz implementation 不收敛；不得静默降频。保存最差路径和物理证据，另行提出有界
  timing closure write set；
- CoreMark image 超出 BRAM 或要求改变当前 memory map；
- DRC/CDC/methodology 处理要求修改 CPU、Cache、AXI 或 MMIO 语义；
- 任一 candidate 不能证明实际消费了对应 COE。

### PC-U：自己的 Pipeline SoC EGO1 用户板测

状态：Pending；仅在 PC5 四候选准备完成后进入。

默认 write set：本任务书执行记录。用户不修改 repository source。

执行顺序：

1. `c-test-0`：验证重复 reset、UART 收发、switch、LED 和数码管；
2. `c-test-1`：验证格式化输出、输入回显和外设显示；
3. `c-test-2`：验证递归、heap、timer 和两轮排序；
4. `coremark`：按 50 MHz 参数运行规定时长，记录 CRC、错误计数、迭代和分数；
5. 每次记录 bitstream SHA-256、串口设置、原始 transcript 摘要、外设现象和 PASS/FAIL。

任一失败均回到最小可复现和对应自动层；不得用单周期、其他 candidate、课程 bitstream
或历史 feature branch 结果替代。

### PC6：产品关闭与后续验收交接

状态：Pending。

默认 write set：

- `README.md`
- `AGENTS.md`
- `docs/workflow.md`
- `docs/devlog/README.md`
- `projects/pipeline/BASELINE.md`
- `artifacts/README.md`
- 本任务书

工作：

- 在最终 source 上重跑自动门禁并复核 PC5 candidate/evidence；
- 记录 PC-U 四候选用户结果，关闭 pipeline physical product Not Run；
- 更新仓库状态、产品 provenance、证据索引和后续缺口；
- 确认工作树、submodule 和 canonical project 无生成物污染；
- 经用户确认创建 pipeline 物理产品里程碑 tag；
- 明确官方 IP 拓扑、报告、最终汇编/COE 和提交包仍由下一份任务书接手，不自动进入。

PC6 不创建官方验收对齐任务书，除非用户另行明确授权。

## 总体验收

- PC0～PC6 均以独立、聚焦提交关闭，PC-U 有用户拥有的物理证据；
- pipeline C_TEST 0～2、CoreMark system、五配置 lint/Trace 和 pipeline-control 均在当前
  产品源上通过；
- canonical pipeline Vivado 2023.2 工程可从 clean source 重建；
- 四候选在 50 MHz 下 implementation、timing、DRC、provenance 和 bitstream 均关闭；
- 用户自己的 pipeline bitstream 通过 C_TEST 0～2 与 CoreMark；
- `artifacts/pipeline/` 含当前 source/tool 对应的 timing/utilization/power 文本证据；
- 单周期产品、Trace 合同、两个 submodule 和自有 SoC 功能语义未被破坏；
- 官方 IP/报告/最终提交对齐仍明确为 Pending，并有完整交接输入。

## 完成记录

| Checkpoint | 状态 | 提交 | 验证证据 |
| --- | --- | --- | --- |
| PC0 任务书冻结 | Completed | 本提交 | `just --fmt --check`；`just doctor`；`git diff --check`；docs-only |
| PC1 失败基线与合同 | Pending | — | — |
| PC2 Vivado 产品路径 | Pending | — | — |
| PC3 Pipeline System | Pending | — | — |
| PC4 clean 自动回归/综合 | Pending | — | — |
| PC5 implementation/候选 | Pending | — | — |
| PC-U EGO1 用户板测 | Pending | — | — |
| PC6 产品关闭 | Pending | — | — |

## Write Set 扩展记录

当前无扩展。

后续扩展必须记录：原 write set 为何不足、拟增加的文件及 owner、是否改变外部合同、需要
新增或重跑的验证、用户确认结论和日期。
