# P0 Final Technical Summary

Status: TECHNICAL ARCHITECTURE P0 COMPLETE
Date: 2026-09-27

## Outcome

All six P0 architecture questions now have a technical decision.

P0-3 still has an explicit Human Playtest gate; this is experiential validation, not an unresolved core architecture question.

## Decisions

### P0-1 Data
Selected: YARD v1.2.0.

Production consequence:
- YARD registry + typed Resources are the content authority.
- Domain code accesses a project DefinitionRegistry adapter.
- DataTables is not a second primary database.
- Future CSV/JSON balance tooling may operate around YARD.

### P0-2 Effect / Status
Selected: project-owned lightweight EffectRuntime.

Production consequence:
- tags/stacks/duration/cleanse/simple modifiers remain a small deterministic service.
- BattleResolver owns Counter/Intercept/Link timing and action ordering.
- GodotGAS remains a reference, not a production dependency.

Evidence:
- Round 1 Run 36253352684 success.
- Round 2 Run 36253967168 success.

### P0-3 Battle
Selected technical baseline:
- per-character Draw/Discard
- 2-card quota each, 6 visible total
- Retain
- same-character Redraw
- 3 Card Plays
- one free adjacent Formation Adjustment
- Sync as advanced team resource
- visible Intent
- isolated battle_draw / enemy_ai RNG
- pure BattleState + BattleCommand + BattleResolver

Evidence:
- integrated deterministic Run 36256390743 success
- 12 turns / 57 commands / command-by-command deterministic replay

Remaining:
- Human Playtest and full experiential input/readability validation.

### P0-4 Inventory
Selected: lightweight project-owned Inventory Domain.

Rejected as runtime authority: GLoot 3.0.2.

Evidence:
- Final Run 36261935089 success.
- Atomic transfer, save round-trip, missing-definition Fail Closed and emergency extraction passed.

### P0-5 Event
Selected: thin project-owned Event Domain + Dialogue Manager v4.1.0 presentation.

Authority:
- YARD: EventDefinition
- WorldState: permanent state
- EventResolver/EventCommands: business consequences
- Dialogue Manager: narrative presentation / option_id only

Evidence:
- Final Run 36282696128 success.
- GdUnit 7/7 + full headless integration smoke.

### P0-6 Save
Selected: SaveState Lite v2.0.0.

Authority:
- project: DTO/schema/migrations/stable-ID policies
- SaveState: validated I/O/retained generations/recovery

Evidence:
- Final Run 36283764675 success.
- SaveState passed every hard requirement.
- Enhanced Save failed newer-schema rejection and lacked retained-generation/automatic recovery behavior required by the project.

## Locked third-party baseline

Locked:
- Godot 4.7.1 stable
- YARD v1.2.0
- Dialogue Manager v4.1.0
- SaveState Lite v2.0.0
- GdUnit4 v6.2.1 (development)

Provisional pending Human Playtest:
- Card Framework v1.4.0, presentation only

See `third_party/dependencies.lock.json`.

## Locked project-owned architecture

- DefinitionRegistry adapter
- EffectRuntime
- Battle Domain
- Inventory Domain
- World/Fortress/Character state
- Event Domain
- RNG streams
- Save DTO/schema/migration layer

## Production Save Schema

The real game's first production Save Schema starts at **1**.

P0 fixture schema v1/v2/v3/v4 are synthetic migration fixtures and do not count as released game schema history.

See:
- `docs/architecture/core-schema-v1.md`
- `docs/architecture/schema.lock.json`

## What is still not decided

Not every optional plugin is now locked.

Still separate decisions when actually needed:
- menu/settings/input helper
- audio manager
- world-map editor/presentation helper
- tween/juice helpers
- runtime profiling
- autosim helper
- mod loader

Follow the same rule: research mature options first, adopt only when they reduce real project complexity, and keep gameplay authority in the project.

## Next gate

The next concrete blocking task is **P0-3 Human Playtest preparation/execution**.

After it:
- finalize Card Framework status
- perform small P0-driven design edits
- lock first production content slice
- create visual sample
- establish formal game mainline
