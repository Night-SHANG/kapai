# Vertical Slice v1 Scope

Status: LOCKED
Date: 2026-09-27

This is the first production-facing playable slice after P0. It is not a throwaway demo and not the full first chapter.

## Product loop

The slice must close this loop:

Fortress -> Prep -> Old City map -> Search/Event -> Battle -> Threat rise -> Continue or Extract -> Loot/Overweight -> Normal or Emergency Extraction -> Expedition Result -> Maintenance/Small Upgrade -> Save -> Re-enter.

## P0-3 Human Playtest policy

Do not build a separate Human Playtest build.

Human validation is embedded in the production Battle Scene and the permanent Dev Battle Lab:
- mouse / keyboard / controller
- readability
- 3 Card Plays
- Redraw
- Formation
- Sync
- Intent

Card Framework remains PROVISIONAL_LOCK until this production validation is complete.

## Old City scope

Use only the first Old City outer-ring slice:
- Fortress Outer Ring Station
- Convenience Center
- Municipal Hospital
- Subway Transfer Station
- City Archive

Deferred until after the slice:
- fourth-character recovery at the Construction Zone
- Zero Tower / City Defense Center chapter boss
- complete Chapter 1 closure

## Combat content

Starting characters:
- Bastion
- Falcon
- Loom

Cards:
- 8 production cards per character
- 24 total

Baseline:
- independent per-character Draw / Discard
- 2-card quota each, 6 visible total
- 3 Card Plays
- 2 Redraw
- Retain
- 1 free adjacent Formation Adjustment
- Sync
- visible enemy Intent
- pure BattleState / BattleCommand / BattleResolver

Initial enemy roles:
- melee pressure
- rear / precision attacker
- shield / defense
- support / buff
- one Elite rule combination

## Permanent Dev Battle Lab

The formal project includes a reusable debug/balance scene:
- select production characters/loadouts
- select Normal / Elite / Boss-like test encounter
- fixed seed
- inspect BattleState, RNG streams, Intent and Command Log
- quick restart
- mouse / keyboard / controller input

This is a long-term production tool, not temporary P0 code.

## Events and search

Target 8-12 production EventDefinitions covering:
- basic search
- tool option
- party-tag option
- Threat cost
- item consumption
- WorldFlag / LocationState change
- StartBattle -> BattleContinuation
- Once / Cooldown
- one forward-compatible Research/Authority-style condition

Dialogue Manager remains presentation-only.

## Inventory / loot

Target 10-12 production ItemDefinitions:
- base materials
- medical sample
- key-item sample
- 3-4 expedition tools
- Scrap / Data / Core as long-term resources

Required behavior:
- hard weight limit
- stack/split/merge
- secure storage
- overweight selection
- emergency extraction keep/loss rules

## Threat and extraction

The slice must prove the game's main differentiator:
- movement raises Threat
- battles raise Threat
- events may raise/lower Threat
- Stage changes are legible
- after the objective, the player chooses whether to keep pushing or leave
- normal extraction works
- emergency extraction can be triggered and resolved

## Fortress minimum

Only production functions required for the loop:
- Fortress overview
- expedition entry
- squad/loadout/tool prep
- warehouse
- basic maintenance
- one basic workshop/upgrade result
- minimal world/codex feedback
- Save / Continue / Recovery UI

Not in Slice v1:
- full research tree
- reconstruction
- transcendence
- large facility tree
- full character personal stories

## UI scope

Production pages:
1. Main Menu / Continue / Load
2. Fortress
3. Expedition Prep
4. Old City node map
5. Location Search/Event
6. Battle
7. Loot / Overweight / Emergency Extraction
8. Expedition Result
9. minimal Character / Deck / Inspect
10. Settings entries required for display/audio/control/accessibility

A shared Modal Layer is established immediately.

## Save / recovery

Use SaveState Lite v2.0.0 with production save_schema_version = 1.

Required:
- New Game
- Continue
- node-settlement autosave
- battle safe-boundary save
- expedition settlement save
- fortress save
- explicit recovery flow when newest generation is damaged

## Visual sample before implementation

Only three core reference images are required before the production mainline:
- Fortress overview
- Old City region map
- Standard battle

They establish UI language, density, card readability, character/enemy/background scale, and placement of Threat / Intent / Formation.

## Completion

Automated:
- Production Preflight green
- GdUnit/domain regression green
- reference/localization/save/determinism checks green
- Godot 4.7.1 Windows Build + Package + Smoke green

Human:
- combat readability
- Card Plays / Redraw / Formation / Sync feel
- mouse / keyboard / controller
- Threat risk/reward comprehension
- visual readability

Human playtest is part of production slice acceptance, not a separate pre-production project.
