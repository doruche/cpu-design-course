# 开发环境与本地依赖整理任务书

## 状态

- 状态：Completed（E0～E3 已完成）
- 建立日期：2026-07-30
- 基线提交：`51fd795`
- 性质：开发环境、宿主能力与本地输入的说明/诊断整理；不是 RTL、Vivado 产品或课程材料迁移任务

本任务将仓库的可复现 Linux 开发路径，与必须由个人宿主提供的课程材料、Vivado 和物理
设备条件明确分开。目标是让新的开发者能判断某条命令在何处可运行、缺少某项能力时会影响
什么，而不是把受限材料或专有工具塞入 devcontainer。

## 已冻结的环境边界

| 类别 | Canonical owner | 是否版本控制 | 影响范围 |
| --- | --- | --- | --- |
| 核心开发/自动验证工具链 | `.devcontainer/` | 是 | Linux container 中的 `just`、lint、Trace、unit、integration、system 与 closure |
| 课程行为与 golden inputs | `materials/instruction-site/`、`cdp-tests/` pinned submodule | 是 | 课程合同与 Trace 验证 |
| 受限课程下载物与个人历史快照 | `materials/lab1/`、`materials/lab2/`，hash 在 `materials/MANIFEST.md` | 否，Git 忽略 | 阅读、溯源或明确需要该本地输入的动作；不是日常回归的隐式依赖 |
| Vivado 后端 | Windows Vivado 2023.2 + WSL 调用层 + ignored `local.env` | 否 | `just vivado*` 的 staging、综合、实现和 bitstream |
| 物理板、串口与最终提交输入 | 用户/外部 owner | 否 | 烧录、现场观察、报告、ZIP、上传；不由自动化推导 |

当前受支持的 Vivado 路径是 WSL 调用 Windows `vivado.bat`：`scripts/vivado.sh` 需要
`cmd.exe` 与 `wslpath`，并以 `local.env` 中的 `VIVADO_BIN`、`VIVADO_STAGE_ROOT`、
`VIVADO_JOBS` 建立宿主连接。它不等同于 devcontainer 内的普通验证路径。`STUDENT_ID`
及最终导出所需的身份/文件路径仍是显式命令输入，不进入 `local.env`。

## 目标

1. 给出一份单一、可链接的环境合同，说明每种能力的 owner、前提、配置位置、验证入口和
   缺失影响。
2. 让 README 的入门路径清楚区分“container 内日常开发”和“WSL/Windows Vivado 后端”。
3. 让 `just doctor` 的输出能区分核心工具链失败、未配置的可选 Vivado 能力和未提供的受限
   本地材料，而不把它们混写为 RTL/产品失败。
4. 保持课程材料不被自动下载、复制进镜像或提交到 Git；保持 Windows staging 为派生树。

## 明确非目标

- 不修改 RTL、设计 CSV、测试 oracle、配置矩阵、XPR/XCI/XDC/COE 或课程 submodule；
- 不在容器中安装、分发或模拟 Vivado，不新增原生 Linux Vivado 支持；
- 不下载、提交、重分发或替换 `materials/lab1/`、`materials/lab2/` 中的材料；
- 不修改现有 Vivado 实现/bitstream/板测证据，不重新运行这些物理门禁；
- 不把学号、姓名、报告路径、板卡串口或其他提交身份写入共享配置；
- 不更改 `just doctor` 的核心失败语义，除非 E2 的最小诊断设计获得确认。

## 执行规则

1. 严格按 E0、E1、E2、E3 执行；未关闭前一检查点不得自动进入下一项。
2. E1 只整理文档和模板，不得以文档变更宣称容器、Vivado 或板级验证重新通过。
3. E2 只补现有公开诊断入口的分类与 fail-closed 边界；不得创建第二套环境配置格式或
   自动安装/下载路径。
4. 课程材料的缺失只在实际依赖它的动作中成为阻塞条件；核心开发/自动验证不得隐式依赖
   ignored `materials/lab*/`。
5. 任何需要改动 Dockerfile、Vivado staging 语义、公开 CLI、材料位置或产品合同的发现，
   都先停止并记录新增 owner、原因和验证影响，待用户确认后再扩展 write set。

## E0：任务书与边界冻结

状态：Completed（2026-07-30；docs-only，未进入 E1）。

### Write set

- `docs/devlog/development-environment-local-dependencies.md`
- `docs/devlog/README.md`

### 工作

- 固化核心 container、pinned submodule、ignored course materials、WSL/Windows Vivado 和
  用户物理操作之间的 owner/生命周期边界；
- 冻结后续文档、诊断和关闭检查点的最小 write set、验证门禁与停止条件；
- 将任务书登记为 Active，不修改任何环境实现或产品文件。

### 验证门禁

```bash
just --fmt --check
git diff --check
git status --short
```

E0 仅证明任务范围已经冻结，不证明 devcontainer 可构建、材料可取得、Vivado 可访问或板卡可用。

## E1：环境合同与入口文档

状态：Completed（2026-07-30；docs-only，进入 E2 的诊断缺口已确认）。

### 默认 Write set

- `docs/environment.md`（新建，唯一环境合同入口）
- `README.md`
- `docs/workflow.md`
- `AGENTS.md`（只增加指向环境合同的阅读入口）
- `materials/MANIFEST.md`
- `local.env.example`
- 本任务书执行记录

### 工作

- 写明四类能力的最小前提、配置位置、可运行命令、失败解释及 owner；
- 将 README 快速开始拆为 container 日常开发与 WSL/Windows Vivado 两条路径；
- 说明 `local.env` 的严格三键边界、环境变量覆盖规则、Windows 可见 disposable staging
  要求，以及它不保存身份或受限材料路径；
- 将 `materials/MANIFEST.md` 明确为受限本地输入的 provenance/hash 清单，而不是自动化
  下载清单或日常构建前提；
- 不改动 `.devcontainer/`、`Justfile`、`scripts/` 或 `.gitignore`。

### 验证门禁

```bash
just --fmt --check
git diff --check
rg -n 'local\.env|VIVADO_|materials/lab[12]|devcontainer' README.md docs AGENTS.md materials/MANIFEST.md
```

### 停止条件

- 无法从 live scripts 区分某项能力是核心依赖、可选能力还是用户操作；
- 文档需要承诺原生 Linux Vivado、自动材料下载或容器内板卡访问；
- 发现现有公开命令隐式消费 ignored material 或未记录的宿主路径。

### 执行记录

- 新建 `docs/environment.md` 作为唯一环境合同入口，并从 README、workflow、agent 指引、
  manifest 与 `local.env.example` 链接到它；未修改 `.devcontainer/`、`Justfile`、`scripts/`、
  `.gitignore`、RTL、课程 submodule 或 Vivado 产品文件。
- 从 live `scripts/build.sh`、`scripts/vivado.sh`、`scripts/local-settings.sh` 与 Trace backend
  确认：日常公开验证只消费 tracked 源和 pinned submodule；ignored `materials/lab*/` 不被这些
  日常动作隐式读取；Vivado 是 WSL 调用 Windows `vivado.bat` 的派生 staging 后端。
- 门禁通过：`just --fmt --check`、`git diff --check`，以及任务书指定的 `rg -n
  'local\\.env|VIVADO_|materials/lab[12]|devcontainer' README.md docs AGENTS.md
  materials/MANIFEST.md`。
- `just doctor` 的 live 输出仍将核心工具、RV32 ABI、pinned repository inputs 与 Vivado 混在
  通用 optional/单一 batch 行中，且没有受限材料状态。因此 E2 有明确的最小诊断表达缺口；
  不以 E1 文档门禁宣称容器、Vivado 或板级动作重新通过。

## E2：最小环境诊断对齐

状态：Completed（2026-07-30；最小诊断对齐，未运行 Vivado）。

### 默认 Write set

- `Justfile`
- `scripts/doctor.sh`
- `scripts/local-settings.sh`（仅在现有三键校验确有缺口时）
- `docs/environment.md`
- `README.md`
- `docs/workflow.md`
- 本任务书执行记录

### 工作

- 仅在 E1 确认存在诊断表达缺口时，为既有 `just doctor` 增加可区分的 capability 状态；
- 核心 container 工具链继续决定普通 `just doctor` 的成功/失败；Vivado、WSL 兼容层和
  受限本地材料必须以明确状态呈现，且只在相应操作请求时 fail closed；
- 不新增第二套配置文件、环境安装器、材料下载器或绕过 `just` 的公开入口。

### 验证门禁

```bash
bash -n scripts/doctor.sh scripts/local-settings.sh
just doctor
just --fmt --check
git diff --check
```

### 停止条件

- 诊断变更会使没有 Vivado 或本地材料的 container 开发路径无法使用；
- 需要读取、写入或猜测用户的 Windows 路径、证书、板卡、串口或课程账户；
- 需要变更 Vivado staging、候选选择或产品验证合同。

### 执行记录

- 仅修改既有 `scripts/doctor.sh`，未修改 `Justfile`、`scripts/local-settings.sh`、Vivado
  staging、候选选择、产品配置或材料位置。现有三键解析器已经对未知键、重复键、空值和
  非正 `VIVADO_JOBS` fail closed，因此不扩大其 write set。
- Required tools、版本、RV32IM/ILP32 probe 与 Repository inputs 仍是唯一影响普通
  `just doctor` exit status 的核心检查。`materials/lab1/`、`materials/lab2/` 只报告
  `[provided]` 或 `[not provided]`；无材料不会计为核心失败，也不触发 hash、下载或复制。
- Vivado 段现在单列 `local.env` 的 `[misconfigured]`、三键/默认值、`cmd.exe`/`wslpath`
  bridge、`[not configured]`/`[not available]` 与最终 `[ready]`/`[not ready]` 状态。错误的
  `local.env` 不再使普通 doctor 失败；实际 `just vivado*` 继续使用同一解析器并 fail closed。
- 门禁通过：`bash -n scripts/doctor.sh scripts/local-settings.sh`、`just doctor`、
  `just --fmt --check` 与 `git diff --check`。本机显示两个材料目录 `[provided]`，以及
  已配置的 WSL/Windows Vivado capability；输出明确注明未运行任何 Vivado action，不能作为
  综合、实现、bitstream 或板级新证据。

## E3：收口

状态：Completed（2026-07-30）。

### 默认 Write set

- `docs/devlog/README.md`
- 本任务书执行记录

### 工作与验证

- 复核 E1 的环境合同与 E2（若执行）的诊断结果一致，扫描旧的个人环境暗示；
- 保持所有未运行的 Vivado/板级动作按真实状态表述；
- 运行 `just --fmt --check`、`just doctor`、`git diff --check` 与 `git status --short`；
- 将任务移入 Completed。是否创建 tag 由用户另行决定，本任务默认不创建。

### 执行记录

- 复核 `docs/environment.md`、README、workflow、`local.env.example`、manifest、doctor 与
  `.gitignore` 的 owner、三键和 capability 表述一致；`git check-ignore -v` 确认
  `materials/lab1/`、`materials/lab2/`、`local.env` 仍分别由既有 ignore 规则保护。
- 扫描当前文档、脚本、配置和程序入口的路径/材料引用。`programs/` 中对 Lab 2 archive 的引用
  是已导入程序的 provenance，不是运行时读取；`docs/acceptance/` 中的 `Z:`/`/mnt/z` 路径是
  已关闭 Vivado 证据的来源位置，不是新的共享环境配置。二者均不需要、也不应在本任务中改写。
- 未运行 Vivado、bitstream、烧录或板级动作；本任务只新增环境合同与 doctor capability
  诊断，不能更新任何物理产品证据。默认不创建 tag。
- 最终门禁见本任务关闭时的 `just --fmt --check`、`just doctor`、`git diff --check` 与
  `git status --short` 输出。

## 总体验收

- 新开发者能从一处找到 container、受限材料、WSL/Windows Vivado 和物理操作的边界；
- 正常自动验证不依赖个人材料、Windows 路径或 Vivado 安装；
- 需要宿主能力的公开入口明确前提与失败方式，不将“未配置”误写为产品失败；
- 课程材料、完整 Vivado run、bitstream 与身份/提交文件仍不进入 Git 或容器镜像；
- 本任务不产生 RTL、Vivado 或板级新证据。
