# P0-1 — Data Layer

目标：在 Godot 4.7.1 stable / Windows x64 上，以同一套 fixture 比较 YARD v1.2.0 与 Godot DataTables v1.0.1。

当前状态：工作包已建立，尚未标记 P0_VERIFIED。

源码审计阶段 YARD 更符合本项目的 Stable ID、Git/Codex 单实体编辑、Resource-first 与低锁定要求；DataTables 的优势是 Schema-first、强类型、表格批量编辑和 CSV/JSON。P0 用真实 4.7.1 项目量化这些差异。

一键运行：

1. 设置环境变量 GODOT_EXE 指向 Godot_v4.7.1-stable_win64.exe，或给 run_p0.ps1 传 -GodotExe。
2. 运行：pwsh .\poc\data_layer\run_p0.ps1

依赖：Git、Python 3、Godot 4.7.1 stable。

自动步骤：验证引擎版本；生成确定性 fixture；安装固定插件；初始化两个隔离项目；YARD 生成 100 个独立 Card Resource 和 Registry；DataTables 生成 100-row DataTable；分别执行 Headless Preflight。

自动脚本通过后仍需继续做 Git merge、Schema 演进、Codex 编辑、批量平衡和 Editor UX 实验。结果记录在 docs/results/P0-1-data-layer.md。
