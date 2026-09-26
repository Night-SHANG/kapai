# kapai

Godot 2D 末日科幻小队远征 + 三人卡牌战斗项目。

## 当前阶段

当前仓库处于 **P0 / Preflight 验证阶段**，不是正式游戏主干。

目标不是提前制作完整游戏，而是用隔离、可丢弃的 PoC 验证关键架构：

1. 数据层：YARD vs Godot DataTables
2. Effect / Status：GodotGAS vs 轻量模型
3. 三人卡牌战斗：抽牌公平性 + 3 Card Plays vs 共享 4 AP
4. Inventory：GLoot vs 轻量 ItemStack
5. 世界事件链：EventDefinition → Dialogue → Command → WorldState
6. 存档：SaveState Lite vs Enhanced Save System

六个 P0 完成后，才锁定正式依赖、数据 Schema、技术架构；随后修订最终文字方案、制作视觉样板，再进入正式开发。

## 引擎基线

- Godot **4.7.1 stable**
- Windows x64
- 用户本地可执行文件：`Godot_v4.7.1-stable_win64.exe`

除非明确执行引擎升级流程，否则 P0、Preflight、CI 与正式开发都必须使用 4.7.1 stable。

## 知识与代码职责

- **Notion**：项目设计、母版研究、技术决策、P0 结论、开发记录、变更说明的长期知识库。
- **GitHub / 本仓库**：可执行代码、测试、fixtures、Preflight、CI、依赖锁与结果文件。

聊天中的重要结论需要同步回 Notion；代码改动则在 Notion 记录其用途与结果。

## 目录

```text
docs/
  decisions/           # P0 最终技术裁决
  architecture/        # P0 后正式架构文档
  results/             # P0 实测结果摘要（不放巨型二进制）
poc/
  data_layer/          # P0-1
  effect_layer/        # P0-2
  battle/              # P0-3
  inventory/           # P0-4
  events/              # P0-5
  save/                # P0-6
scripts/
  preflight/           # 通用 Preflight / 版本检查
  tools/               # fixture/数据生成等开发脚本
third_party/
  README.md            # 第三方依赖安装与许可证说明
```

## P0 状态术语

- `UPSTREAM_SUPPORTED`：上游声明覆盖 Godot 4.7.1。
- `P0_VERIFIED`：已在本项目 Godot 4.7.1 上真实运行验证。
- `LOCKED`：P0 通过并锁定精确 tag/commit。

README/插件声明不能替代本项目实测。

## 当前首个任务

P0-1 数据层对照实验：

- YARD 1.2.x / 固定 commit
- Godot DataTables 1.0.0 / 固定 commit
- GdUnit4 6.2.x
- 同一套 fixture
- 比较 Stable ID、Git diff/merge、Codex 编辑、Schema 演进、Runtime Query、批量平衡与插件锁定风险。

详见 `poc/data_layer/README.md`。
