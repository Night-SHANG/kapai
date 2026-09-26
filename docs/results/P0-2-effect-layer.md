# P0-2 Effect / Status Result

Status: TECHNICAL DECISION COMPLETE — LIGHTWEIGHT SELECTED

Engine: Godot 4.7.1 stable / Windows x64

GodotGAS candidate:
- v1.1.0
- commit 42ae230840bfbe4d62629e6f5d1d5ba1a65a4a3b
- MIT
- released 2026-09-26
- breaking release

Lightweight:
- project-owned minimal EffectRuntime
- no external runtime dependency

## Round 1

Run #3: GitHub Actions 36253352684 — SUCCESS

Both candidates passed:
- GameplayTagQuery / require-all-tags equivalent
- TURN_BASED independent from wall-clock delta
- max stack = 3
- overflow -> Stagger
- cleanse by tag

## Round 2

Run #4: GitHub Actions 36253967168 — SUCCESS

GodotGAS:
- intercept=pass
- counter=pass
- link=pass
- save_dto=pass
- deterministic=pass
- position_modifier=pass
- debug=pass

Lightweight:
- intercept=pass
- counter=pass
- link=pass
- save_dto=pass
- deterministic=pass
- position_modifier=pass
- debug=pass

Observed stable debug DTO:
status_counter stacks=1 turns=1 source=char_bastion

## Important architecture result

Counter / Intercept / Link remained controlled by the Battle Harness in both implementations.

Therefore the Effect layer does not need to own battle flow.

This is important because BattleResolver must remain the authority for:
- action ordering
- target rewrite
- reaction timing
- Sync generation
- damage resolution

## GodotGAS integration observations

Strengths:
- mature tag/query vocabulary
- stack cap/overflow
- declarative cleanse
- turn duration
- attribute modifiers

Costs observed:
- requires normal project lifecycle for GameplayCueManager Autoload
- isolated P0 emits missing cue registry warning
- immediate test exit emits small ObjectDB/resource warnings
- production Save still requires our own stable-ID DTO bridge
- includes ability/input/network/cue systems outside current needs
- v1.1.0 is a same-day breaking release

## Decision

SELECT project-owned lightweight EffectRuntime.

Reason:
The project needs a compact deterministic turn-based effect domain, while most of GodotGAS's additional surface is unused. The lightweight implementation matched every required P0 semantic and keeps Save, replay and BattleResolver boundaries simpler.

GodotGAS remains a reference implementation, not a production dependency.

See:
docs/decisions/effect-layer-decision.md
