# P0-5 World Event Pipeline

Status: PASS — TECHNICAL DECISION COMPLETE

Engine baseline: Godot 4.7.1 stable / Windows x64.

## Existing decisions reused

P0-5 does not reopen earlier decisions:

- YARD v1.2.0 remains the static Definition authority.
- Lightweight project-owned Inventory remains the runtime item-state model.
- Dialogue Manager is narrative/presentation only.
- WorldState remains the permanent world authority.
- UI returns option_id and never writes permanent gameplay state directly.

## Pinned dependencies

- YARD v1.2.0
  - commit 48a518b4bec03c8b5ad446f57a2b669110a1752b
  - MIT
- Dialogue Manager v4.1.0
  - commit a719088aea342572f29b5559fd8726896c9519b2
  - MIT
  - latest stable release checked at P0-5 start; release targets Godot 4.7
- GdUnit4 v6.2.1
  - commit 08ffc7c65b61b1b2edd545616061a99973c13ce1
  - MIT

## Implemented acceptance surface

- YARD EventDefinition resources + stable-ID registry.
- Location/EventDefinition/Condition/Option/Command/WorldState chain.
- Condition base set:
  - HasCharacter
  - PartyHasTag
  - HasItem
  - ItemCountAtLeast
  - HasResearch
  - ResourceAtLeast
  - ThreatRange
  - LocationState
  - WorldFlag
  - EventSeen / EventNotSeen
  - ALL / ANY / NOT
- Command base set:
  - Add/RemoveResource
  - Add/RemoveItem
  - ChangeThreat
  - SetWorldFlag
  - SetLocationState
  - DiscoverLocation
  - UnlockRoute
  - DamageCharacter
  - ApplyInjury
  - StartBattle
  - RestoreFacility
  - UnlockArchive
- Transactional command application.
- Preview derived from the same command data.
- Once and cooldown EventHistory.
- BattleResult continuation for win / retreat / wipe.
- JSON round-trip at committed state boundary.
- Static reference/localization/dialogue-cue validation.
- Static critical-event reachability guard.
- Dialogue mutation ban for P0 event dialogue.
- Real Dialogue Manager cue resolution and option_id-only return bridge.
- GdUnit4 domain tests.
- Headless integration smoke.

## Fixed content

The P0 reuses the pre-agreed sealed-laboratory fixture rather than inventing new gameplay:

- force
- breach
- engineering
- research_auth
- leave

Additional fixtures exist only to test battle continuation and cooldown history.

## Final decision

P0-5 is technically complete.

Selected architecture:

- YARD remains the static EventDefinition authority.
- WorldState remains the sole permanent world-state authority.
- EventConditionEvaluator is pure-read and composable.
- EventResolver owns business execution order.
- EventCommands apply transactionally against draft state and commit only after the full option succeeds.
- Dialogue Manager v4.1.0 remains Narrative/Presentation only.
- Raw .dialogue files are compiled with the real DMCompiler for headless CI; the full Dialogue Manager editor UI is not part of runtime verification.
- UI/presentation returns only option_id to EventResolver.
- Preview is derived from the same command data as execution.
- EventHistory in WorldState owns once/cooldown behavior.
- StartBattle uses explicit pending battle + EventContinuation rather than implicit scene-only signals.
- Save boundary is committed domain state only; unselected UI state is not persisted.
- Critical-event reference/reachability/localization/dialogue mutation checks belong in Game Preflight.

No additional event-framework plugin is adopted as the world-event core. The project keeps a thin custom Event Domain because the remaining logic is project-specific and is now proven headlessly testable.


## Run #2 — Dialogue Manager Headless Editor UI failure

- Run ID: 36281323156
- commit: cbddfd01a9978b62109768c30054c7566f9b90c6
- result: failure

Confirmed before failure:
- all pinned dependencies PASS
- static Event Preflight PASS: 3 events / 14 conditions / 14 commands

Failure:
- Dialogue Manager v4.1.0 full EditorPlugin was enabled during Windows headless editor import.
- DMThemeValues requested editor-theme values that are Nil in this headless environment.
- The failure occurred in editor presentation initialization before Event Domain/GdUnit/runtime smoke.

Correction:
- Dialogue Manager's full EditorPlugin is no longer enabled in P0-5 headless CI.
- The real v4.1.0 DMCompiler.compile_string() compiles canonical raw .dialogue sources into generated DialogueResource .tres files.
- Runtime EventDefinitions point to those generated resources.
- DialogueManager runtime autoload remains enabled.
- This keeps real Dialogue Manager compiler/runtime coverage without coupling P0 verification to its editor UI theme.


## Run #5 — generated EventDefinition UID persistence

- Run ID: 36281750826
- commit: debd7f67a6b62adbcf8eba99e67c6f5dd42ef3ab
- result: failure

Confirmed before failure:
- all pinned dependencies PASS
- static Event Preflight PASS
- headless class scan PASS with Dialogue Manager editor UI disabled
- raw .dialogue -> DialogueResource compile PASS (3 resources)
- EventDefinition generation PASS (3 resources)

Failure:
- YARD registry construction rejected `event_test_sealed_lab.tres` because `ResourceLoader.get_resource_uid()` returned an invalid UID.
- This repeats a Godot 4.7 script-mode behavior already solved in P0-1: `ResourceSaver.save()` alone does not guarantee a generated .tres gets a persisted UID.

Correction:
- reuse the P0-1/YARD resource-generation rule:
  - `ResourceSaver.save(..., ResourceSaver.FLAG_CHANGE_PATH)`
  - `ResourceUID.create_id_for_path(path)`
  - `ResourceSaver.set_uid(path, uid)`
  - register the UID in the running ResourceUID cache if needed
- registry remains fail-closed if any generated resource has no valid UID.

Fix commit:
- `b81e9be1b4ef3597245c0fc1daeee7aa0ca5b4a8`

A new P0 Events run was triggered. Result pending.


## Run #6 — EventHistory JSON round-trip assertion

- Run ID: 36282202655
- commit: b81e9be1b4ef3597245c0fc1daeee7aa0ca5b4a8
- result: failure

Confirmed before failure:
- all pinned dependencies PASS
- static Event Preflight PASS
- Dialogue Manager headless compile PASS
- EventDefinition generation PASS
- YARD registry PASS (3 entries)
- GdUnit4 domain tests PASS (6/6)

Failure:
- full integration smoke stopped at the EventHistory JSON round-trip assertion.
- The assertion compared the whole deserialized Dictionary directly with the pre-serialization Dictionary.
- JSON numeric values can return with a different Variant numeric representation even when their persisted meaning is unchanged.

Correction:
- validate persisted EventHistory semantically:
  - `times`
  - `last_cycle`
  - restored once-event availability behavior
- add a dedicated GdUnit regression test proving JSON round-trip preserves EventHistory semantics.

Fix commit:
- `56d4eb72b7daaf35ffa0556fb9a51aaa4996c8e0`

A new P0 Events run was triggered. Result pending.


## Run #7 — FINAL PASS

- Run ID: 36282696128
- commit: 56d4eb72b7daaf35ffa0556fb9a51aaa4996c8e0
- result: success
- job: Windows Godot 4.7.1 P0-5

Validated:
- pinned YARD / Dialogue Manager / GdUnit4 dependencies PASS
- static Event Preflight PASS: 3 events / 14 conditions / 14 commands
- raw .dialogue -> DialogueResource compile PASS: 3 resources
- EventDefinition generation PASS: 3 resources
- YARD registry PASS: 3 stable-ID entries
- GdUnit4 PASS: 7/7, 0 failures
- FTL-style special option availability PASS
- command atomicity PASS
- command-derived preview PASS
- Once / Cooldown / EventHistory PASS
- EventHistory JSON round-trip semantics PASS
- StartBattle + win/retreat/wipe continuation path PASS
- runtime event-chain reachability PASS
- Dialogue Manager presentation-only bridge PASS
- option_id return PASS
- WorldState unchanged by presentation PASS
- full headless integration smoke PASS

Artifact:
- name: p0-5-events-results
- ID: 10919412153
- SHA256: 6cfe7b9774c71c8785e961412ece62a71a7c04662d817c168fc747234fa88244

Non-blocking observations:
- GdUnit startup reports remote debugger port 0 and headless graphics/audio fallback warnings.
- Final smoke exits with 3 ObjectDB instances and 2 resources still in use.
- These are P0 harness cleanup debt, not failures of the selected Event Domain architecture.

P0-5 technical stage is closed. Next technical validation: P0-6 Save / Restore / Migration.
