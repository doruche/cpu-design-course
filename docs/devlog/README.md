# Development Log

本目录保存仓库本地开发任务书和执行记录。它们用于约束具体工作的范围、顺序与
验证门禁，不替代固定版本的课程指导书、Trace 实现或持续维护的设计 CSV。

## Active Tasks

- [单周期 SoC 开发](single-cycle-soc.md) — Active；Stage 0～3 已完成，Stage 3
  里程碑为 `single-cycle-soc-stage3`，构建/验证间章待实施，Stage 4 未开始。
- [构建系统、CLI 与完整 SoC 验证间章](build-cli-and-soc-verification.md) — Planned；
  迁移根构建入口到 `just`，整理配置与验证分层，并补齐 CPU 驱动的产品拓扑测试。

## Completed Tasks

- [单周期 RTL 清理与微重构](single-cycle-rtl-cleanup.md) — Done，2026-07-23；三个
  实现 checkpoint 均已独立提交并通过规定门禁。
