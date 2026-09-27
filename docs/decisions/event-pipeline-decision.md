# Event Pipeline Decision

Status: ACCEPTED
P0: P0-5
Validated on: Godot 4.7.1 stable / Windows x64
Final workflow run: 36282696128
Final validated commit: 56d4eb72b7daaf35ffa0556fb9a51aaa4996c8e0

## Decision

Use a thin project-owned Event Domain.

Authoritative flow:

LocationState
-> EventSelector
-> YARD EventDefinition
-> EventConditionEvaluator
-> Available Option IDs
-> Dialogue Manager presentation
-> option_id
-> EventResolver
-> EventCommands
-> WorldState / ExpeditionState / Inventory
-> Save

## Ownership

YARD:
- static EventDefinition authority
- stable event IDs and resource registry

WorldState:
- permanent world authority
- location state
- world flags
- discovered locations / routes
- restored facilities
- research
- EventHistory

Event Domain:
- pure Conditions
- available-option calculation
- transactional Command execution
- command-derived Preview
- Once / Cooldown
- StartBattle continuation contract

Dialogue Manager v4.1.0:
- dialogue text
- cue/branch presentation
- option labels
- runtime dialogue resource resolution
- returns option_id only

Dialogue Manager must not directly mutate inventory, threat, location state, world flags, research, or other permanent gameplay state.

## Headless compilation boundary

Dialogue Manager's full EditorPlugin is not enabled in P0 headless CI because its editor-theme UI requires editor settings unavailable in the Windows headless environment.

Instead:

raw .dialogue
-> Dialogue Manager v4.1.0 DMCompiler.compile_string()
-> generated DialogueResource .tres
-> DialogueManager runtime

This still validates the real Dialogue Manager compiler/runtime while keeping editor UI outside the runtime architecture boundary.

## Transaction rule

An option resolves against a draft state.

If any EventCommand fails:
- no later Command is committed
- no earlier Command is committed
- WorldState remains unchanged

Only after all Commands succeed is the draft committed.

## Save boundary

Persist committed domain state only.

Do not persist:
- unselected option UI
- transient dialogue popup state

Persist:
- EventHistory
- world/location state changes
- resources/items already committed
- explicit pending battle continuation state when an event started a battle

## Preflight rules

Fail closed on:
- missing stable references
- missing localization keys
- missing dialogue cues
- duplicate/empty option IDs
- gameplay mutation inside dialogue source
- unknown Condition or Command types
- structurally unreachable critical events
- generated YARD resources without valid persisted UIDs

## Final evidence

Run 36282696128: success.

- 3 events
- 14 Condition types
- 14 Command types
- YARD registry: 3 entries
- GdUnit4: 7/7 PASS
- full headless Event pipeline smoke: PASS
- Dialogue Manager presentation-only boundary: PASS
- BattleContinuation: PASS
- Save-boundary JSON round-trip semantics: PASS

Artifact:
- p0-5-events-results
- ID 10919412153
- SHA256 6cfe7b9774c71c8785e961412ece62a71a7c04662d817c168fc747234fa88244

## Rejected / postponed

- FlowKit as world-event core: rejected for this project.
- Dialogue mutation as permanent business logic: rejected.
- per-event custom GDScript as the default model: rejected.
- QuestSystem as a second permanent truth source: postponed unless the game later needs a traditional quest-log/objective/reward domain.

## Result

P0-5 technical decision complete.

This architecture is the baseline for formal implementation after the remaining P0 work. Next P0: P0-6 Save / Restore / Migration.
