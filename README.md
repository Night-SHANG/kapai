# kapai

Godot 2D 末日科幻小队远征 + 三人卡牌战斗项目。

## 当前阶段

六个 P0 的**技术架构裁决已经完成**，但尚未进入正式游戏主干开发。

当前剩余关键门槛：
1. P0-3 Human Playtest（基础战 / Elite / Boss-like，鼠标 / 键盘 / 手柄与可读性）。
2. 根据试玩最终确认 Card Framework 的正式状态。
3. P0 后少量规则修订。
4. 锁定第一章 / Vertical Slice 最小正式内容范围。
5. 制作视觉样板。
6. 建立正式 game mainline 与 Production Preflight。

## P0 最终技术基线

- P0-1 Data：YARD。
- P0-2 Effect / Status：项目自有轻量 EffectRuntime。
- P0-3 Battle：三人独立牌堆 + 2×3 手牌 + 3 Card Plays + 1 次相邻 Formation + Sync；技术验证完成，Human Playtest Pending。
- P0-4 Inventory：项目自有轻量 Inventory Domain。
- P0-5 Event：项目自有薄 Event Domain + Dialogue Manager 表现层。
- P0-6 Save：SaveState Lite v2.0.0。

详见：
- `docs/decisions/p0-final-summary.md`
- `docs/architecture/production-baseline-v1.md`
- `docs/architecture/core-schema-v1.md`
- `third_party/dependencies.lock.json`

## 引擎基线

- Godot **4.7.1 stable**
- Official build：`4.7.1.stable.official.a13da4feb`
- Windows x64
- 本地可执行文件：`Godot_v4.7.1-stable_win64.exe`

除非执行正式升级流程，否则 Preflight、CI 与正式开发都使用 4.7.1 stable。

## 知识与代码职责

- **Notion**：项目设计、母版研究、技术决策、P0 结论、开发记录、变更说明的长期知识库。
- **GitHub / 本仓库**：可执行代码、测试、fixtures、Preflight、CI、依赖锁与结果文件。

重要结论同步回 Notion；可执行事实进入 GitHub。

## 目录

```text
docs/
  decisions/           # P0 最终技术裁决与汇总
  architecture/        # P0 后正式架构与 Schema 基线
  results/             # P0 实测结果摘要
poc/
  data_layer/          # P0-1
  effect_layer/        # P0-2
  battle/              # P0-3
  inventory/           # P0-4
  events/              # P0-5
  save/                # P0-6
scripts/
  preflight/           # 通用 / 项目契约 Preflight
  tools/               # fixture / 数据工具
third_party/
  dependencies.lock.json
  README.md
```

## 状态术语

- `P0_VERIFIED`：已在本项目 Godot 4.7.1 上真实验证。
- `LOCKED`：正式基线锁定精确 tag/commit。
- `PROVISIONAL_LOCK`：精确版本已固定，但仍有明确人工验收门槛。

当前 Card Framework 属于 `PROVISIONAL_LOCK`，直到 P0-3 Human Playtest 完成。

## 开发纪律

- 通用系统先找成熟轮子，再决定复用、包装或自研。
- 玩法机制先研究成熟商业范式。
- Definition 与 Runtime State 分离。
- Save 只存 stable ID 和项目 DTO，不持久化插件运行时对象。
- UI/表现层不得直接改权威 Domain State。
- 修改后先 Level 1 / Preflight，再完整 Build/Package/Runtime。
- 可自动发现的问题尽量沉淀成新的 Preflight/回归规则。
