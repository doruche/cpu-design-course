# Development Log

本目录保存仓库本地开发任务书和执行记录。它们用于约束具体工作的范围、顺序与
验证门禁，不替代固定版本的课程指导书、Trace 实现或持续维护的设计 CSV。

## Active Tasks

当前无 Active Tasks。

## Completed Tasks

- [开发环境与本地依赖整理](development-environment-local-dependencies.md) — Completed，
  2026-07-30；E0～E3 已关闭。container 核心工具链、受限本地材料、WSL/Windows Vivado
  后端与用户物理操作的 owner/前提/失败边界已整理；未修改 RTL、Vivado 产品路径或课程
  材料位置，也未产生新的 Vivado/板级证据。
- [课程现场验收准备与官方材料采集](course-acceptance-readiness.md) — Completed，
  2026-07-30；AR0～AR5、AR-R 均已关闭，用户确认当前现场验收完成。任务仅覆盖流水线
  实验二的截图、provenance 材料与现场准备；报告正文/PDF、最终 ZIP 和上传仍由外部 owner
  管理。
- [流水线 SoC 产品闭环](pipeline-soc-product-closure.md) — Completed，2026-07-30；
  PC0～PC6 与 PC-U 均已完成，流水线 C_TEST/CoreMark 自动证明、canonical Vivado 2023.2、
  50 MHz clean implementation、四候选 bitstream 和用户 EGO1 板测已关闭，里程碑为
  `pipeline-soc-stage5`；官方 IP/报告/提交对齐仍由后续独立任务接手。
- [流水线 CPU 与流水线 SoC 合并记录](pipeline-cpu-and-soc.md) — Completed，
  2026-07-30；五级核、SoC fabric 与 Linux RTL/仿真范围已合入 `main`，剩余工程和物理
  产品工作由“流水线 SoC 产品闭环”任务书接手。
- [流水线 merge 后稳定化维护](pipeline-post-merge-maintenance.md) — Completed，
  2026-07-29；M0～M2 已完成，M3 经只读预检未发现有证据支持的 RTL 整理目标并由用户
  确认跳过；产品 RTL 未修改，pipeline 产品闭环缺口继续由独立任务接手。
- [单周期 SoC 开发](single-cycle-soc.md) — Completed，2026-07-28；Stage 0～5、
  自有 bitstream 与 EGO1 板测均已关闭，里程碑为 `single-cycle-soc-stage5`。
- [单周期 SoC Stage 5：物理工程与自有板级闭环](single-cycle-soc-stage5.md) —
  Completed，2026-07-28；S5-0～S5-4 与 S5-U 均已完成，三套自有候选已通过
  clean Vivado 实现、审计和用户 EGO1 板测。
- [单周期 SoC Stage 4：C_TEST 软件与自动化联调](single-cycle-soc-stage4.md) —
  Completed，2026-07-27；S4-1～S4-3 自动范围和 S4-U 课程 bitstream 用户板测均通过。
- [构建系统、CLI 与完整 SoC 验证间章](build-cli-and-soc-verification.md) — Completed，
  2026-07-26；公开入口已切换到 Just，六配置与 CPU-driven SoC smoke 已关闭验证。
- [单周期 RTL 清理与微重构](single-cycle-rtl-cleanup.md) — Done，2026-07-23；三个
  实现 checkpoint 均已独立提交并通过规定门禁。
