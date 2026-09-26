# P0-2 — Effect / Status

基线：Godot 4.7.1 stable / Windows x64。

目标：比较 GodotGAS 与最小轻量 Effect Runtime，而不是比较“成熟框架 vs 一堆卡牌 if/else”。

## GodotGAS 候选

- Release: v1.1.0
- Commit: 42ae230840bfbe4d62629e6f5d1d5ba1a65a4a3b
- License: MIT
- 上游声明: Godot 4.6+
- 注意：2026-09-26 当日发布，Release 明确标注 Breaking Changes。
- plugin.cfg 内部仍写 v1.0.7，因此依赖身份只认 Tag + Commit。

上一正式版 v1.0.6 已有 TURN_BASED / advance_turn，但没有 v1.1.0 完整的 max_stacks / stack_count / overflow_effects / declarative cleanser / GameplayTagQuery。

## 第一轮验证

两种实现用相同语义：

1. TURN_BASED 2 回合状态。
2. Break 最多 3 层并触发 overflow。
3. Cleanse by Tag。
4. Tag Query：必须拥有 Mark 才能应用 Exposed。
5. Headless / Godot 4.7.1。

第一轮只证明底座，不做最终裁决。

## 第二轮（第一轮通过后）

- Counter
- Intercept
- Link
- Save DTO round-trip
- deterministic replay
- Debug dump
- Position Modifier
- 10 个正式测试 Status

最终才决定 GodotGAS 或 lightweight。
