# 开发环境与本地依赖

本页是本仓库环境能力的唯一合同入口。它说明每项能力由谁提供、在哪里配置、用哪个公开命令验证，以及缺失时影响什么；课程行为和 Trace 的具体合同仍以两个 pinned submodule 的 live source 为准。

## 能力边界

| 能力 | Owner 与版本控制 | 最小前提和配置位置 | 验证入口 | 缺失时的影响 |
| --- | --- | --- | --- | --- |
| Linux 日常开发与自动验证 | `.devcontainer/`，以及已初始化的 `cdp-tests/`、`materials/instruction-site/` pinned submodule；均进入 Git | 在 devcontainer 中打开仓库，执行 `git submodule update --init --recursive` | `just doctor`，随后按需执行 `just lint`、`just trace`、`just unit`、`just integration`、`just system` 或 `just gate` | 缺少必需工具、仓库输入或正确的 submodule pin 时，`just doctor` 失败；这不是 RTL 或产品行为失败 |
| 受限课程下载物和个人快照 | 用户本地的 ignored `materials/lab1/`、`materials/lab2/`；provenance 和 SHA-256 记录在 `materials/MANIFEST.md` | 仅在需要阅读、复核 provenance 或重新取得某个原始输入时由用户提供 | `just doctor` 只报告目录是否提供；按 `materials/MANIFEST.md` 人工核对来源和 hash | 缺失不阻塞日常自动验证，也不会触发下载；只阻塞真正需要那个本地输入的动作 |
| WSL/Windows Vivado 后端 | 用户安装的 Windows Vivado 2023.2、WSL 兼容层和 ignored `local.env` | 在 WSL 中从 `local.env.example` 创建 `local.env`，或预先导出同名环境变量；需有 `cmd.exe`、`wslpath`、可执行的 `VIVADO_BIN` 和 Windows 可见的 disposable `VIVADO_STAGE_ROOT` | `just doctor` 报告能力状态；`just vivado <product> <stage|synth|bitstream>` 或显式候选命令执行实际动作 | 未配置或不可用不影响 Linux 日常验证；请求 Vivado 动作时公开入口 fail closed |
| 物理板、串口和最终提交 | 用户或外部 owner；不进入 Git 或容器 | 用户的 EGO1、连接、现场观察，以及导出时显式提供的身份和文件路径 | `just program <name>` 只构建和审计程序镜像；`just export-submission` 要求显式的 `STUDENT_ID`、`STUDENT_NAME`、`REPORT_PDF`、`PROGRAM_ASM`、`PROGRAM_COE` | 自动化不能推导烧录、板上现象、报告、ZIP 或上传结果；这些动作仍由 owner 完成并记录 |

## Linux 日常开发

`.devcontainer/` 是核心 Linux 工具链的 canonical owner。它提供本仓库公开 CLI 所需的编译器、Verilator、Icarus、RISC-V 交叉工具链和辅助命令；它不包含 Vivado、课程下载物或物理设备访问。

首次在 container 中打开仓库后执行：

```bash
git submodule update --init --recursive
just doctor
just show-config pipeline-soc-cache
just lint pipeline-soc-cache
```

`just doctor` 的 Required tools、RV32IM/ILP32 probe 与 Repository inputs 是这条路径的 fail-closed 检查。`cdp-tests/` 是 Trace 的序列化后端，不是第二个公开 CLI；所有日常命令仍从根 `Justfile` 进入。

## 受限材料

`materials/MANIFEST.md` 记录可取得的原始课程下载物和用户快照的来源、用途与 SHA-256。它不是下载器、镜像构建输入或“每次构建前必须补齐”的清单。不要自动下载、复制、提交或重分发 `materials/lab1/` 和 `materials/lab2/`，也不要将它们的路径写入 `local.env`。

日常 `just lint`、Trace、unit、integration、system 和 closure 只使用 tracked 产品源、测试和 pinned submodule；已导入的程序和维护中的 RTL 也不在运行时读取这些 ignored 目录。某个历史材料确实被要求时，先按 manifest 核对其 provenance/hash，再在该动作的记录中说明其使用；材料不存在本身不是 RTL、Trace 或产品失败。

## WSL/Windows Vivado 后端

这是一条宿主后端，不是 devcontainer 内的普通验证路径。当前公开实现从 WSL 调用 Windows 的 `vivado.bat`：`scripts/vivado.sh` 先将 canonical `projects/<product>/` 单向复制到 staging，再让 Vivado 在该派生树执行。绝不在 Windows staging 中修复源文件；应在 WSL canonical project 中修复后重新 stage。

创建 ignored 的 `local.env`：

```bash
cp local.env.example local.env
```

文件只允许下列三个未加引号、未加 `export` 的 literal `KEY=VALUE` 值：

| 键 | 用途 |
| --- | --- |
| `VIVADO_BIN` | WSL 路径形式的 Windows Vivado 2023.2 `vivado.bat` |
| `VIVADO_STAGE_ROOT` | WSL 路径形式、Windows 可见的 disposable staging 根目录；不得位于 canonical product tree 内 |
| `VIVADO_JOBS` | 正整数，并行作业数 |

若同名环境变量已导出，它优先于 `local.env` 中的值。`local.env` 不保存 `STUDENT_ID`、姓名、报告/程序路径、串口、板卡配置或课程材料路径。`stage` 只需要可写的 staging root；`synth` 与 `bitstream` 还要求 `cmd.exe`、`wslpath` 和可访问的 `VIVADO_BIN`。bitstream 一律通过显式候选名选择，例如：

```bash
just vivado-candidate-for pipeline coremark bitstream
```

`just doctor` 的 Vivado 和材料段是 capability 报告：`[not configured]`、`[not available]` 或 `[not provided]` 不改变核心 Linux 开发路径的成功状态。相应的 Vivado 或材料消费者才会在缺少前提时退出；不要用临时脚本绕过根 `Justfile`。

## 物理与提交边界

`just program` 生成可审计程序镜像，`just system` 是 RTL 仿真；二者均不烧录 EGO1，也不观察串口或板上外设。物理操作、现场现象、最终报告、提交 ZIP 和上传需要用户明确提供设备或输入，并以真实状态记录。已存在的 Vivado、bitstream 或板级证据也不会因为修改本文档而重新获得验证。
