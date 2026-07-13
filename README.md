# CPU Design Course Workspace

本仓库用于哈尔滨工业大学（深圳）2026 夏季《计算机设计与实践》课程。
当前选择为 **EGO1 + miniRV**，目标是以单人工作流完成课程完整范围，而不是按
单人最低要求裁剪功能。

## 当前状态

- Lab 1 官方 `miniRV_basic_ego1` 工程已经导入并打基线 tag：
  `upstream-lab1-template`。
- `projects/single_cycle/src/rtl/` 是当前唯一 HDL 真相源。
- Trace 框架和指导书以固定 commit 的 Git submodule 引入。
- 官方模板已使用本机 Verilator 通过七项绿色 Trace 基线套件；`lw` 用例同时
  覆盖模板实现的 `lui`。
- Vivado 2023.2 尚未接入；安装后通过 Windows staging 和 batch Tcl 验证。

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

运行模板当前的绿色基线套件：

```bash
make trace-demo
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
│   └── pipeline/           # Lab 1 完成后派生，当前尚未创建
├── cdp-tests/              # 固定版本的 Trace submodule
├── materials/
│   ├── instruction-site/   # 固定版本的官方指导书 submodule
│   ├── lab1/               # 本地下载物，Git 忽略
│   └── MANIFEST.md         # 下载物哈希和依赖版本
├── design/                 # 数据通路、控制表和可编辑设计图
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
- [官方 Trace 说明](materials/instruction-site/docs/trace/trace.md)
- [官方提交要求](materials/instruction-site/docs/home/submit.md)

课程材料仅限本课程使用。本仓库应保持私有，不得重新分发指导书和下载包。
