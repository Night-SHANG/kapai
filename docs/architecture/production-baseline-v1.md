# Production Architecture Baseline v1

Status: LOCKED AFTER P0 TECHNICAL VALIDATION
Engine: Godot 4.7.1 stable
Scope: architecture baseline before formal game-mainline implementation

## 1. Core rule

External plugins provide infrastructure or presentation where they are strong. Project-owned Domain layers retain gameplay authority.

No plugin is allowed to become a second source of truth for a state that the project already owns.

## 2. Layer model

### Content / Definition layer
**YARD v1.2.0** is the static content registry.

Project code sees it through a thin `DefinitionRegistry` adapter:
- has(id)
- load(id)
- list_ids()
- validate references
- query/filter when justified

Definitions are ordinary typed Godot Resources keyed by stable business IDs.

### Domain layer
Project-owned:
- World/Fortress/Character state
- lightweight EffectRuntime
- BattleState/BattleCommand/BattleResolver
- lightweight Inventory Domain
- Event Condition/Resolver/Commands
- RNG stream service
- Save DTO/schema/migrations

This layer is pure/headless-testable wherever practical.

### Presentation layer
**Card Framework v1.4.0**:
- card/hand/pile visuals and interaction presentation only
- provisional final lock until P0-3 Human Playtest is complete

**Dialogue Manager v4.1.0**:
- dialogue text
- narrative branches/cues
- option presentation
- returns `option_id`

Neither may directly mutate authoritative gameplay state.

Future map/UI/audio/tween helpers remain optional and are not yet part of the architecture lock.

### Persistence layer
**SaveState Lite v2.0.0**:
- storage
- validation
- immutable retained generations
- history/recovery
- atomic generation commit

Project owns the DTO and all business migration semantics.

### Test / quality layer
**GdUnit4 v6.2.1** plus project Preflight.

The Preflight system is the executable form of architecture knowledge: once a failure can be detected automatically, it should become a regression/contract rule.

## 3. Authoritative flows

### Battle
Input (mouse/keyboard/gamepad)
-> CardSelection/Input adapter
-> BattleCommand
-> BattleResolver
-> EffectRuntime / RNG services
-> new BattleState
-> presentation reads state

Selected baseline:
- 3 characters
- 8 equipped cards each
- independent Draw/Discard per character
- 2-card quota each / combined 6 visible
- same-character Redraw
- Retain
- 3 Card Plays per turn
- rare explicit Heavy may consume 2
- 1 free adjacent formation adjustment
- Sync as separate cooperation resource
- visible enemy Intent
- separate battle_draw / enemy_ai RNG

### Event
LocationState
-> EventSelector
-> YARD EventDefinition
-> pure EventConditionEvaluator
-> available option IDs
-> Dialogue Manager presentation
-> option_id
-> EventResolver
-> transactional EventCommands
-> WorldState / Expedition / Inventory
-> Save

### Inventory
UI/Command
-> Inventory Domain validation
-> atomic draft/operation
-> committed InventoryState

Static item values resolve from YARD by item_id.

### Save / Restore
Domain state
-> project Save DTO
-> SaveState Lite
-> retained generation

Load:
SaveState Lite validation/recovery
-> project schema migration
-> project semantic validation
-> stable-ID re-resolution through DefinitionRegistry
-> authoritative runtime states

A corrupted or future-schema save never silently becomes New Game.

## 4. Authority matrix

| Concern | Authority | External helper |
|---|---|---|
| Static Definitions | YARD via DefinitionRegistry | YARD |
| Permanent world state | WorldState | none |
| Status/effect semantics | EffectRuntime | none |
| Battle order/rules | BattleResolver | Card Framework presentation only |
| Inventory business rules | Inventory Domain | none |
| Event business consequences | EventResolver/EventCommands | Dialogue Manager presentation only |
| Dialogue text/branch display | Dialogue Manager | Dialogue Manager |
| Save business schema/migrations | project Save DTO layer | SaveState Lite I/O/recovery |
| Gameplay RNG | project RNG service | none |
| Automated tests | project test suites | GdUnit4 |

## 5. P0 decisions carried forward

P0-1: YARD selected over DataTables as the primary content authority.

P0-2: project lightweight EffectRuntime selected over GodotGAS.

P0-3: technical battle baseline selected; Card Framework passed presentation/input smoke but remains subject to Human Playtest.

P0-4: lightweight Inventory Domain selected over GLoot runtime.

P0-5: thin Event Domain + Dialogue Manager presentation selected; WorldState remains sole permanent world authority.

P0-6: SaveState Lite v2.0.0 selected over Enhanced Save System.

## 6. Explicitly not production dependencies

P0 comparison candidates retained only as references/evidence:
- Godot DataTables
- GodotGAS
- GLoot
- Enhanced Save System
- FlowKit

They must not appear in the formal runtime addon set without a new architecture decision and affected regression suite.

## 7. Remaining gates before formal mainline

Technical architecture is no longer the blocker.

Still required:
1. P0-3 Human Playtest: basic / Elite / Boss-like session; mouse, keyboard and controller; targeting/readability/formation UI.
2. Confirm Card Framework remains acceptable after that playtest.
3. Lock first production content slice (first chapter/minimum vertical slice).
4. P0-result-driven text cleanup: only rules actually affected by P0.
5. Produce visual sample(s) after the rules are stable.
6. Establish the formal game project directory and production Preflight around these locked contracts.

Do not copy entire P0 implementations blindly into production. Promote only proven contracts and reusable code after review.
