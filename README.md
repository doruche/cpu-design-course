# CPU Design Course Workspace

本仓库用于哈尔滨工业大学（深圳）2026 夏季《计算机设计与实践》课程。
当前选择为 **EGO1 + miniRV**，目标是以单人工作流完成课程完整范围，而不是按
单人最低要求裁剪功能。

## 当前状态

- Lab 1 完整单周期 CPU 已完成；2026-07-20 复核时 `make lint` 和全部 45 项
  Trace（包括修复后的 `start`）均通过。
- Lab 1 官方 `miniRV_basic_ego1` 工程的导入基线 tag 为
  `upstream-lab1-template`；完整 Lab 1 状态由 `lab1-complete` tag 保存。
- `projects/single_cycle/src/rtl/` 和 `projects/pipeline/src/rtl/` 分别是两套产品的
  HDL 真相源。
- Trace 框架和指导书以固定 commit 的 Git submodule 引入。
- 指导书已固定到包含 Lab 2-A 和 Lab 2-B 的版本。
- Vivado 2023.2 的 WSL-to-Windows batch 入口已经配置，Lab 1 综合和实现已在
  Windows 侧完成。Lab 1 不要求下板，本里程碑未做也不声明板级验证。
- Lab 2 双产品基线已经建立；`projects/pipeline/` 当前仍是 `lab1-complete` 的原样
  副本，尚未开始流水线 RTL 改造。

## 快速开始

首次取得仓库后初始化依赖：

```bash
git submodule update --init --recursive
make doctor
```

运行单个 Trace 测试：

```bash
make trace TEST=addi
```

运行完整 Basic Trace：

```bash
make trace-all
```

查看所有入口：

```bash
make help
```

## 目录边界

```text
.
├── projects/
│   ├── single_cycle/       # 单周期 CPU，Lab 2 继续演化为单周期 SoC
│   └── pipeline/           # 从 lab1-complete 派生，先做流水线 CPU，再集成 SoC
├── cdp-tests/              # 固定版本的 Trace submodule
├── materials/
│   ├── instruction-site/   # 固定版本的官方指导书 submodule
│   ├── lab1/               # 本地下载物；课件归档在 ppt/，Git 忽略
│   ├── lab2/               # 本地材料快照；课件归档在 ppt/，Git 忽略
│   └── MANIFEST.md         # 下载物哈希和依赖版本
├── design/                 # 持续维护的数据通路表和控制信号表 CSV
├── programs/               # 板上程序源码；COE 由源码生成
├── artifacts/              # 精选的正式 Vivado 报告
├── docs/                   # 本项目工作流，不复制指导书
└── scripts/                # Trace、Vivado staging 和导出脚本
```

不要在 `cdp-tests/mySoC/` 或 Windows staging 中开发。课程提交所需的平铺源码
由导出命令生成，不构成第二份真相。

## 文档入口

- [项目工作流](docs/workflow.md)
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
