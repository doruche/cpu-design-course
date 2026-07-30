# CPU Design Course Workspace

本仓库用于哈尔滨工业大学（深圳）2026 夏季《计算机设计与实践》课程。
当前选择为 **EGO1 + miniRV**，目标是以单人工作流完成课程完整范围，而不是按
单人最低要求裁剪功能。

## 当前状态

- Lab 1 完整单周期 CPU 已完成；2026-07-20 复核时 lint 和全部 45 项 Trace
  （包括修复后的 `start`）均通过。
- Lab 1 官方 `miniRV_basic_ego1` 工程的导入基线 tag 为
  `upstream-lab1-template`；完整 Lab 1 状态由 `lab1-complete` tag 保存。
- `projects/single_cycle/src/rtl/` 和 `projects/pipeline/src/rtl/` 分别是两套产品的
  HDL 真相源。
- Trace 框架和指导书以固定 commit 的 Git submodule 引入。
- 指导书已固定到包含 Lab 2-A 和 Lab 2-B 的版本。
- Vivado 2023.2 的 WSL-to-Windows batch 入口已经配置，Lab 1 综合和实现已在
  Windows 侧完成。Lab 1 不要求下板，本里程碑未做也不声明板级验证。
- Lab 2 流水线产品已经从完整单周期基线演化为 IF/ID/EX/MEM/WB 五级核，并接入
  已验证的 Cache、AXI、主存/MMIO interconnect 和外设 fabric。五个 pipeline 配置的
  lint 与全部 45 项 Trace、流水线 C_TEST 0～2 和 CoreMark RTL system suite 已通过；
  canonical Vivado 2023.2 工程已在 50 MHz 下完成 clean implementation，四个可追溯
  C_TEST/CoreMark bitstream 均通过机器审计和 EGO1 用户板测。CoreMark 本次板测为
  49.7197 CoreMark、0.9943 CoreMark/MHz，物理产品里程碑 tag 为
  `pipeline-soc-stage5`。现场验收准备与官方材料采集已由独立任务书关闭；数据通路图和
  报告撰写由外部 owner 负责，当前验收口径不要求迁移 Vendor IP。
- 单周期 SoC Stage 0～3 已完成，里程碑 tag 为 `single-cycle-soc-stage3`。默认产品
  路径已经接入 Cache、AXI 主存/MMIO 互连和五类外设；Stage 3 的完整链路、错误事务、
  子字访问和外设边界均有仓库测试。Stage 4 的 C_TEST 0～2、可审计程序镜像和三套
  CPU-driven System suite 已实现；学号身份已写入默认候选构建，课程 miniRV + EGO1
  bitstream 的三套用户板测均已通过。Stage 5 也已完成：自有 SoC 物理工程、
  50 MHz clean Vivado implementation、三套可追溯 bitstream 和 EGO1 用户板测均已关闭，
  里程碑 tag 为 `single-cycle-soc-stage5`。单周期正式 artifacts 由现场验收材料任务整理，
  数据通路图由外部 owner 负责。
  历史 ROM/RAM 路径仍由独立 Basic Trace profile 保留。
- 仓库公开构建与验证 CLI 已统一为根 `Justfile`。十个稳定配置显式区分两个产品、
  Basic/AXI direct/product SoC 拓扑、Cache、后端和产物目录；Cache-enabled
  CPU-driven SoC smoke 已覆盖主存和五类 MMIO。

## 快速开始

首次取得仓库后初始化依赖：

```bash
git submodule update --init --recursive
just doctor
```

运行单个 AXI Trace 测试（Cache 旁路）：

```bash
just trace single-axi-direct-bypass addi
```

运行完整历史 Basic Trace：

```bash
just trace-all single-basic
```

运行单周期 SoC Stage 3 完整自动化门禁：

```bash
just gate single-stage3
```

运行 CPU 驱动的 Cache-enabled SoC 系统仿真：

```bash
just system soc-smoke
```

构建并运行一个 Stage 4 C_TEST（默认学号为 `2024311488`，也可用 `STUDENT_ID` 覆盖）：

```bash
just program c-test-0
just system c-test-0
```

在流水线 SoC 上构建并仿真运行 CoreMark：

```bash
just program coremark
just system coremark
```

查看所有入口：

```bash
just --list
```

## 目录边界

```text
.
├── Justfile                # 唯一公开构建与验证 CLI
├── config/                 # 稳定配置清单与 lint waiver
├── projects/
│   ├── single_cycle/       # 单周期 CPU，Lab 2 继续演化为单周期 SoC
│   └── pipeline/           # 从当前单周期基线派生，先做流水线 CPU，再集成 SoC
├── cdp-tests/              # 固定版本的 Trace submodule
├── materials/
│   ├── instruction-site/   # 固定版本的官方指导书 submodule
│   ├── lab1/               # 本地下载物；课件归档在 ppt/，Git 忽略
│   ├── lab2/               # 本地材料快照；课件归档在 ppt/，Git 忽略
│   └── MANIFEST.md         # 下载物哈希和依赖版本
├── design/                 # 持续维护的数据通路表和控制信号表 CSV
├── programs/               # 板上程序源码；COE 由源码生成
├── tests/                  # Unit、Integration 与 System testbench/程序
├── artifacts/              # 精选的正式 Vivado 报告
├── docs/                   # 本项目工作流，不复制指导书
└── scripts/                # Trace、Vivado staging 和导出脚本
```

不要在 `cdp-tests/mySoC/` 或 Windows staging 中开发。课程提交所需的平铺源码
由导出命令生成，不构成第二份真相。

## 文档入口

- [项目工作流](docs/workflow.md)
- [开发任务日志](docs/devlog/README.md)
- [课程现场验收准备与官方材料采集任务书](docs/devlog/course-acceptance-readiness.md)
- [流水线 SoC 产品闭环任务书](docs/devlog/pipeline-soc-product-closure.md)
- [流水线 merge 后稳定化维护任务书](docs/devlog/pipeline-post-merge-maintenance.md)
- [流水线 CPU/SoC 合并记录](docs/devlog/pipeline-cpu-and-soc.md)
- [单周期 SoC Stage 5 任务书](docs/devlog/single-cycle-soc-stage5.md)
- [官方模板验证基线](docs/baseline.md)
- [设计产物门禁](design/README.md)
- [正式构建证据](artifacts/README.md)
- [板上程序构建约束](programs/README.md)
- [课程材料清单](materials/MANIFEST.md)
- [官方课程任务说明](materials/instruction-site/docs/index.md)
- [官方 Lab 2-A 流水线要求](materials/instruction-site/docs/lab2-A/0-overview.md)
- [官方 Lab 2-B SoC 要求](materials/instruction-site/docs/lab2-B/0-overview.md)
- [官方 Trace 说明](materials/instruction-site/docs/trace/trace.md)
- [官方提交要求](materials/instruction-site/docs/home/submit.md)

课程材料仅限本课程使用。本仓库应保持私有，不得重新分发指导书和下载包。
