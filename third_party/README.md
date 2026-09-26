# Third-party dependencies

本仓库当前不直接提交第三方插件源码。P0 使用脚本从上游仓库按固定 Tag + Commit 安装到各自隔离项目的 addons/。

目的：避免误跟踪 main；明确实际测试版本；每个 P0 只安装最小依赖；未来正式锁定后再决定 vendoring/submodule/安装脚本策略。

P0-1 当前锁定候选：

- YARD v1.2.0 @ 48a518b4bec03c8b5ad446f57a2b669110a1752b — MIT
- Godot DataTables v1.0.1 @ f405b187b013e3914b812db201f014ac946335a3 — MIT
- GdUnit4 v6.2.1 @ 08ffc7c65b61b1b2edd545616061a99973c13ce1 — MIT

注意：DataTables v1.0.1 Release 加入 enum support，但当前 plugin.cfg 仍报告 1.0.0。因此依赖身份以 Tag + Commit 为准。

正式分发前还要生成完整 Third-Party Notices。
