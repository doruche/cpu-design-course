# CPU Design Course Workspace

本仓库用于哈尔滨工业大学（深圳）2026 夏季《计算机设计与实践》课程。
当前选择为 **EGO1 + miniRV**，目标是完整完成课程范围的所有内容。

## 快速开始

环境 owner、可选宿主能力和缺失影响见[开发环境与本地依赖](docs/environment.md)。日常开发在
Linux devcontainer 中进行；Windows Vivado、受限材料和物理设备不是这条路径的隐式依赖。

### Container 内的日常开发

首次在 container 中打开仓库后检查核心工具链：

```bash
just doctor
```

`just doctor` 的 Required tools、RV32IM/ILP32 runtime ABI 和 Repository inputs 必须通过。
Trace 套件已 vendored 在 `tests/cdp/`，无需初始化；官方指导书快照是 Git 忽略的本地输入，
需要自行放置到 `docs/instruction-site/` 才能通过 Repository inputs 检查。它显示的
Vivado `[not ...]` 状态是可选能力提示，不是 RTL 或产品失败。

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

### WSL/Windows Vivado 后端

Vivado 不在 container 中安装或模拟。仅在 WSL 已能调用 Windows Vivado 2023.2 时，复制
`local.env.example` 为 ignored 的 `local.env`，填写严格的三个 `VIVADO_*` 键，并使用公开入口：

```bash
just vivado pipeline stage
just vivado-candidate-for pipeline coremark bitstream
```

`VIVADO_STAGE_ROOT` 必须是 Windows 可见的 disposable staging 根目录，不能是 canonical
project；完整前提、环境变量优先级和 fail-closed 行为见[环境合同](docs/environment.md)。这些命令不等同于容器内的 lint/Trace/system 验证。

### 受限材料与物理操作

`docs/instruction-site/` 是 ignored 的本地指导书快照，其 provenance/hash 清单在
[`docs/MANIFEST.md`](docs/MANIFEST.md)。不要自动下载或把它放入镜像；lint、Trace、
unit、integration 与 system 验证不在运行时读取它。烧录、串口和板上观察由用户完成；`just program` 与 `just system` 不替代物理
验证。最终导出所需的身份和文件路径通过 `just export-submission` 的显式环境变量提供，不写入
`local.env`。

## 目录边界

```text
.
├── Justfile                # 唯一公开构建与验证 CLI
├── config/                 # 稳定配置清单与 lint waiver
├── projects/
│   ├── single_cycle/       # 单周期 CPU，Lab 2 继续演化为单周期 SoC
│   └── pipeline/           # 从当前单周期基线派生，先做流水线 CPU，再集成 SoC
├── programs/               # 板上程序源码；COE 由源码生成
├── tests/                  # Unit、Integration 与 System testbench/程序
│   └── cdp/                # 固定版本的 Trace 套件
├── docs/                   # 本项目工作流，不复制指导书
│   ├── MANIFEST.md         # 下载物哈希和依赖版本
│   ├── instruction-site/   # 官方指导书本地快照，Git 忽略
│   └── acceptance/         # 精选的正式 Vivado 报告与验收材料
│       └── design/         # 持续维护的数据通路表和控制信号表 CSV
└── scripts/                # Trace、Vivado staging 和导出脚本
```

不要在 `tests/cdp/mySoC/` 或 Windows staging 中开发。课程提交所需的平铺源码
由导出命令生成，不构成第二份真相。

## 文档入口

- [项目工作流](docs/workflow.md)
- [开发环境与本地依赖](docs/environment.md)
- [开发任务日志](docs/devlog/README.md)
- [课程现场验收准备与官方材料采集任务书](docs/devlog/course-acceptance-readiness.md)
- [流水线 SoC 产品闭环任务书](docs/devlog/pipeline-soc-product-closure.md)
- [流水线 merge 后稳定化维护任务书](docs/devlog/pipeline-post-merge-maintenance.md)
- [流水线 CPU/SoC 合并记录](docs/devlog/pipeline-cpu-and-soc.md)
- [单周期 SoC Stage 5 任务书](docs/devlog/single-cycle-soc-stage5.md)
- [官方模板验证基线](docs/baseline.md)
- [设计产物门禁](docs/acceptance/design/README.md)
- [正式构建证据](docs/acceptance/README.md)
- [板上程序构建约束](programs/README.md)
- [课程材料清单](docs/MANIFEST.md)
- [官方课程任务说明](docs/instruction-site/index.md)
- [官方 Lab 2-A 流水线要求](docs/instruction-site/lab2-A/0-overview.md)
- [官方 Lab 2-B SoC 要求](docs/instruction-site/lab2-B/0-overview.md)
- [官方 Trace 说明](docs/instruction-site/trace/trace.md)
- [官方提交要求](docs/instruction-site/home/submit.md)

课程材料仅限本课程使用。本仓库应保持私有，不得重新分发指导书和下载包。
