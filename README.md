# kapai

Godot 2D 末日科幻小队远征 + 三人卡牌战斗项目。

## 当前阶段

六个 P0 的**技术架构裁决已经完成**，正式依赖、Core Schema v1、Architecture Lock 和 Vertical Slice v1 范围均已锁定。

不再单独开发 P0-3 Human Playtest Build。人工战斗体验验收合并进正式 Vertical Slice 的 Battle Scene / Dev Battle Lab。

当前开发前只剩：
1. 堡垒总览视觉样板。
2. 旧城区区域地图视觉样板。
3. 标准战斗视觉样板。
4. 随后建立正式 game mainline，并一次性搭起 Vertical Slice Production Skeleton + Preflight。

## P0 最终技术基线

- P0-1 Data：YARD。
- P0-2 Effect / Status：项目自有轻量 EffectRuntime。
- P0-3 Battle：三人独立牌堆 + 2×3 手牌 + 3 Card Plays + 1 次相邻 Formation + Sync；技术验证完成，人工体验验证并入正式 Vertical Slice。
- P0-4 Inventory：项目自有轻量 Inventory Domain。
- P0-5 Event：项目自有薄 Event Domain + Dialogue Manager 表现层。
- P0-6 Save：SaveState Lite v2.0.0。

详见：
- `docs/decisions/p0-final-summary.md`
- `docs/architecture/production-baseline-v1.md`
- `docs/architecture/core-schema-v1.md`
- `docs/planning/vertical-slice-v1.md`
- `docs/planning/ai-native-execution.md`
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
  planning/            # Vertical Slice 与 AI-native 执行计划
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

当前 Card Framework 属于 `PROVISIONAL_LOCK`，直到正式 Vertical Slice 的 Battle Scene / Dev Battle Lab 完成人工体验验收。

## 开发纪律

- 通用系统先找成熟轮子，再决定复用、包装或自研。
- 玩法机制先研究成熟商业范式。
- Definition 与 Runtime State 分离。
- Save 只存 stable ID 和项目 DTO，不持久化插件运行时对象。
- UI/表现层不得直接改权威 Domain State。
- 修改后先 Level 1 / Preflight，再完整 Build/Package/Runtime。
- 可自动发现的问题尽量沉淀成新的 Preflight/回归规则。
- 默认采用 AI-native 批处理：按依赖/风险/可验证性分批，不按人类 Sprint 或人工工时人为拆小。
- 若正式实现可以承担验证，不额外制造会被丢弃的临时版本。
