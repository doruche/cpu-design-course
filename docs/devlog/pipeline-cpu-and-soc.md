# 流水线 CPU 与流水线 SoC：`feat/pipeline` 迭代交接

## 状态

- 状态：Active（A 线与汇合线自动化范围已关闭；物理与板级范围未开始）
- 分支：`feat/pipeline`，领先 `main` 39 个提交，落后 0 个（可 fast-forward 合并）
- 当前提交：`ad6319c`
- 产品：`projects/pipeline/`
- 主验证配置：`pipeline-basic`（Trace）、`pipeline-soc-cache`（CoreMark 系统仿真）
- 目标板：EGO1（XC7A35TCSG324-1）；时钟合同 50 MHz
- 本文档写作时未重跑任何门禁，下文"已通过"均引用对应提交当时记录的结果

本文是 `feat/pipeline` 的交接件：记录这条分支上已经关闭的范围、可复现的入口、
性能基线，以及必须由下一位执行者（或用户）接手的缺口。范围划界与三条工作线的
定义见 [`materials/lab2-requirements-snapshot.md`](../../materials/lab2-requirements-snapshot.md)，
本文不复制其正文。

## 已关闭的范围

### A 线：流水线 CPU

| 提交 | 内容 |
| --- | --- |
| `cc80842` | 补齐 `design/pipeline/{stage_registers,hazards,flow_control}.csv` 三份设计合同 |
| `63a5bb1` | 按 CSV 实现 IF/ID/EX/MEM/WB 五级核：四组段寄存器、EX 前递网络、WB→ID 读端口旁路、load-use 检测、`flow_control.csv` 的冲刷/暂停优先级 |

`63a5bb1` 中值得交接的三个决定：

1. 取指与访存接口都是无界延迟，因此 IF 和 MEM 各只允许一个在途请求；IF 只在
   IF/ID 将空时发起，保证返回的指令一定有落点，EX 重定向时把在途取指标记为丢弃。
2. 分支在 EX 解析，静态"默认不跳转"；乘除单元按电平启动，EX 在单元启动后撤下
   操作码并在 busy 落下的当拍锁存结果，避免下游暂停导致单元被反复重启。
3. 未编码 rs1/rs2 的指令格式一律上报 x0，使立即数位不会进入前递比较器和
   load-use 检测。

### 汇合线：流水线 SoC 与 CoreMark

| 提交 | 内容 |
| --- | --- |
| `4103ee0` | 把 Cache、`axi_master`、interconnect、外设和拓扑选择顶层移植为 pipeline 产品自己的 HDL truth source；新增四行配置；解除"非 Basic 拓扑仅限 single_cycle"的限制 |
| `e305953` | CoreMark 板级程序构建与验证：`programs/c_test/runtime/freestanding/` 提供缺失的 libc 声明，`scripts/build-coremark.sh` 独立构建路径，`just system coremark` 校验三个与迭代次数无关的 CRC |
| `6f4409c` | `closure` 门禁扩展到全部十个配置，并纳入 CoreMark 系统套件 |
| `e82fd24` | devcontainer 固定工具链（见 [devcontainer 约定](#环境)） |

fabric 无需为流水线核修改：接口相同，且仲裁优先级本来就假设主设备可以同时有一次
取指和一次访存在途——这一点单周期 CPU 从未真正触发过。

### 性能优化（要求 (9)）

基线与两次优化均在 `pipeline-soc-cache` 上、单次 CoreMark 迭代测得：

| 提交 | 改动 | cycles | IPC | 主要停顿变化 |
| --- | --- | --- | --- | --- |
| `e8dc5a4` | 只加测量：cycles / retired / 停顿归因 | 1,692,827 | 0.192 | md=650,422 ifetch=457,689 mem=258,034 |
| `f405c53` | Booth 加法与移位融合为一拍，32 位乘法 ~64→~32 拍 | 1,382,771 | 0.236 | md 650,422→340,374（−18.3% 总周期） |
| `ad6319c` | 取指每拍一次请求：`ifetch_ready` 握手、ICache 命中/回填答复可背靠背接收、IF_ID 后一级 skid buffer | 1,112,667 | 0.293 | ifetch 457,674→138,554（−19.5% 总周期） |

累计 −34.3%，IPC 0.192→0.293。

`ad6319c` 顺带修了一个被两拍取指长期掩盖的前递缺陷：被 hold 的 EX 原先继续使用
ID 阶段捕获的操作数，而其生产者会在 EX 等待期间继续下移，前递可能在指令获准离开
之前消失；现在被 hold 的 EX 会捕获当拍可见的操作数。

## 可复现入口

```bash
just lint pipeline-basic
just trace-all pipeline-basic          # 45 个 Basic Trace 用例
just trace-all pipeline-soc-cache      # AXI Trace（Cache 启用）
just system coremark                   # pipeline-soc-cache 上的 CoreMark CRC 校验
just gate closure                      # 十配置全量扫描，含上述全部
```

配置矩阵已从六行扩到十行：`pipeline-basic` 外新增
`pipeline-axi-direct-{bypass,cache}` 与 `pipeline-soc-{bypass,cache}`。

## 未关闭的缺口

按接手成本从低到高排列。前四项是自动化范围，后三项需要用户或 Vivado/板级参与。

### 1. pipeline 产品的 Vivado 路径停留在 Stage 5 之前

单周期产品在 Stage 5 关闭的物理构建能力没有随 fabric 一起移植：

- `projects/pipeline/src/rtl/ip/bram_axi/bram_axi.xci` 已带 Stage 5 的 38,400 word
  深度，但其 `Coe_File` 指向 `../../../coe/stage5-placeholder.coe`，而该文件
  **在 pipeline 产品下不存在**（只有单周期产品有）。IP 生成会直接失败，这是
  接手第一步要修的一行。
- `projects/pipeline/scripts/build.tcl` 是三参数旧版：没有 Vivado 2023.2 版本钉、
  没有候选 COE 选择、没有 `write_fact` 证据输出。
- `projects/pipeline/miniRV.xpr` 只引用 `clock.xdc` 和 `miniRV_SoC.xdc`，没有单周期
  产品的 `stage5.xdc`。
- `scripts/vivado.sh` 的证据采集分支（`collect_vivado_evidence.py`）与
  `vivado-candidate` 都以 `product == single_cycle` 为条件，pipeline 走 else 分支：
  Vivado 会跑，但实现后时序、未约束路径和 DRC 不会被自动判定。

因此当前 `just vivado pipeline synth` 不是可信门禁，且 `bitstream` 无法产出带
程序的候选。**注意 RTL 侧不欠账**：`projects/pipeline/src/rtl/miniRV_SoC.v` 与单周期
产品当前逐字节相同，Stage 5 的时钟/复位修复已经在内。

### 2. C_TEST 未在流水线 SoC 上重跑

`scripts/build.sh:system_c_test` 硬编码 `load_config single-soc-cache`，
`just system c-test-{0,1,2}` 三个套件当前只证明单周期 SoC。汇合线第 5 步
（"在流水线 SoC 上重新运行 C_TEST"）尚未有任何证据。CoreMark 套件已经参数化到
`pipeline-soc-cache`，可作为改法参照。

### 3. `projects/pipeline/BASELINE.md` 已失效

该文件仍写着"pipeline RTL has not started"，并以已被移除的 `make lint PRODUCT=…`
记录验证。它现在会误导接手者，需要改写或删除。

### 4. 里程碑标记缺失

`CLAUDE.md` 约定用 tag 保存里程碑，但仓库当前没有任何 tag——包括 CLAUDE.md 自身
引用的 `lab1-complete`、`single-cycle-soc-stage3`。A4（流水线 CPU 通过 Basic
Trace，`63a5bb1`）是本分支上第一个值得冻结的点。

### 5. 时序与 Fmax 未测，性能优化据此暂停

要求 (10) 给流水线 SoC 设了 50 MHz 下限。剩余停顿预算是 md=335k（30%）与
mem=258k（23%），两条可用杠杆——radix-4 Booth、组合访存地址通路——都是拿组合延迟
换周期数。周期数本身无法判断这种交换是否净赚，因此在用户跑出
`just vivado pipeline synth` 的 Fmax 与时序之前不应盲目继续（这是用户 2026-07-28
的决定，见记忆 `lab2b-perf-handoff`）。

若时钟被提高到 50 MHz 以上，必须同步修改
`programs/c_test/4_coremark/src/coremark/core_portme.c:36` 的 `#define MHZ`，
否则 CoreMark 计时无效。

### 6. CoreMark 只有仿真证据

`just system coremark` 跑的是单次迭代、无 settling delay 的镜像，校验的是与迭代
次数无关的三个 CRC，仿真中达到 0.65 CoreMark/MHz。可上报的分数需要板上十秒运行，
属于用户范围。

### 7. 板级验证与最终交付未开始

流水线 SoC 的 implementation、bitstream、EGO1 烧录与观察均为 **Not Run**。最终交付
所需的双产品时序/资源/功耗对比、报告 PDF 和提交目录封版同样未开始（按 Stage 5 的
划界，这些统一延到两套 SoC 都物理关闭之后）。

## 建议的接手顺序

1. 修 pipeline 产品的 COE 缺失与 `build.tcl`/XPR/`vivado.sh` 的 Stage 5 对齐，
   使 `just vivado pipeline synth` 成为带证据判定的门禁 → 用户跑一次拿 Fmax。
2. 把 `system_c_test` 参数化到产品/配置，在 `pipeline-soc-cache` 上重跑 C_TEST 0～2。
3. 依据 1 的时序结果，决定是否继续要求 (9) 的剩余两条杠杆。
4. 清理 `BASELINE.md`，为 A4 与流水线 SoC 打 tag，把本分支合入 `main`。
5. 物理关闭（用户）：bitstream、烧录、CoreMark 十秒运行、两产品报告数据。

## 环境

全部命令通过 devcontainer 执行，不在宿主机安装工具链：

```bash
devcontainer exec --workspace-folder . just gate closure
```

工具链由 `e82fd24` 的 devcontainer 定义固定；出现 `command not found` 时应修
devcontainer 镜像定义，而不是回退到宿主机安装或跳过验证。
