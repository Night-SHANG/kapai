# Effect / Status Decision

Decision: Project-owned lightweight EffectRuntime

Status: Selected after P0-2 Round 1 + Round 2 technical validation.

Engine baseline: Godot 4.7.1 stable.

Compared candidate:
- GodotGAS v1.1.0
- commit 42ae230840bfbe4d62629e6f5d1d5ba1a65a4a3b
- MIT
- released 2026-09-26
- breaking release

## What GodotGAS proved

Round 1:
- GameplayTagQuery
- turn-based duration
- 3-stack cap
- overflow
- cleanse by tag

Round 2:
- Counter/Intercept/Link can remain outside GAS in Battle Harness
- position modifier apply/revert
- stable-ID Save DTO bridge
- deterministic effect state for identical command sequence
- debug dump

GodotGAS is technically capable on Godot 4.7.1 for this project's effect needs.

## Why lightweight wins

The project only needs a bounded turn-based effect domain.

Counter, Intercept and Link still belong to BattleResolver even when GAS is present. Therefore the decisive value of GAS is mostly:
- tags
- queries
- stacks
- duration
- cleanse
- simple modifiers

The lightweight runtime reproduced those semantics with much less lifecycle coupling.

GodotGAS also brings systems this project does not currently need:
- ability activation framework
- input handling
- multiplayer synchronization
- gameplay cues/autoload
- broader attribute framework
- realtime duration/periodic paths

P0 also exposed extra integration costs:
- normal project lifecycle is required for GameplayCueManager
- isolated project emits missing cue registry warning
- immediate exits report small ObjectDB/resource leak warnings
- Save requires our own bridge anyway
- v1.1.0 is a same-day breaking release

The project benefits more from owning a small deterministic turn-based core than from adopting the full GAS runtime.

## Architecture

Own:
- EffectDefinition
- EffectInstance
- EffectRuntime
- EffectQuery
- EffectTagSet
- EffectSaveDTO

BattleResolver owns:
- Counter timing
- Intercept target rewrite
- Link/Synergy triggers
- action queue
- damage/order/retreat sequencing

EffectRuntime provides:
- tags
- stacks
- refresh
- duration turns
- overflow
- cleanse
- suppression/query
- simple modifier snapshots
- DTO export/import
- debug dump

Do not let cards or enemies directly mutate raw status dictionaries.

## GodotGAS value retained

GodotGAS remains a design/reference source for:
- tag query semantics
- stack overflow semantics
- suppression
- cleanse grouping
- effect context ideas

Do not vendor or depend on it in the production runtime unless later requirements materially exceed the lightweight design.

## Required production tests

The production lightweight runtime must keep regression tests for:
- Shield
- Armor/Break
- Exposed
- Poison/periodic turn tick
- Stun
- Mark consume
- Overload stack/overflow
- Cleanse tag group
- position modifier
- module passive
- Counter/Intercept boundary
- save/restore
- deterministic replay
