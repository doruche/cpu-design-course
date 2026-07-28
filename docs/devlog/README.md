# Development Log

本目录保存仓库本地开发任务书和执行记录。它们用于约束具体工作的范围、顺序与
验证门禁，不替代固定版本的课程指导书、Trace 实现或持续维护的设计 CSV。

## Active Tasks

- [流水线 CPU 与流水线 SoC：`feat/pipeline` 迭代交接](pipeline-cpu-and-soc.md) —
  Active；五级核、SoC fabric、CoreMark 与 −34.3% 性能优化已关闭，Vivado 物理路径、
  流水线 SoC 上的 C_TEST 与板级验证未开始。
- [单周期 SoC 开发](single-cycle-soc.md) — Active；Stage 0～3 已完成，Stage 3
  里程碑为 `single-cycle-soc-stage3`，构建/验证间章与 Stage 4 已完成；Stage 5 Active。
- [单周期 SoC Stage 5：物理工程与自有板级闭环](single-cycle-soc-stage5.md) — Active；
  S5-0～S5-2 已完成，S5-3 自动回归与三套候选待执行，EGO1 烧录与观察由用户执行。
- 当前无 Active 的本地任务书；流水线 CPU/SoC 尚未启动。

## Completed Tasks

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
