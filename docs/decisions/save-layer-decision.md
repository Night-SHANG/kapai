# Save Layer Decision

Status: ACCEPTED
P0: P0-6
Engine: Godot 4.7.1 stable / Windows x64
Final workflow run: 36283764675
Validated commit: 5802f98bdd796aee6161da9fcac41c6cc81ab5c5

## Decision

Use **SaveState Lite v2.0.0** as the project's save I/O, retained-generation, and recovery layer.

Pinned dependency:
- repository: youssof20/savestate
- version: v2.0.0
- commit: 22b912aebbc6b52b3b31f74d3d83fec48b53870c
- license: MIT

Do not use Enhanced Save System as the production save layer for the current architecture.

## Ownership boundary

The project owns:
- Save DTO schema
- schema_version
- game_version metadata
- WorldState serialization contract
- FortressState
- CharacterState
- ResearchState
- InventoryState
- EventHistory
- TutorialState
- ExpeditionState
- BattleState at safe boundaries
- RNG stream state
- ordered migration functions
- stable-ID alias / replacement / removal policy
- post-load Registry resolution and validation
- recovery UX
- autosave commit points

SaveState Lite owns only:
- validated persistence
- atomic generation commit
- retained generations
- load validation
- explicit load results
- generation history
- recovery selection
- storage plumbing

Gameplay code must never depend on plugin runtime objects as durable save data.

## Why SaveState Lite

On Godot 4.7.1 it passed every P0-6 hard requirement:
- current schema round-trip
- mid-expedition restore
- deterministic battle resume
- v1 -> v2 -> v3 ordered migration
- direct older-schema migration to current
- stable-ID alias migration
- missing critical ID fail-closed
- newer schema rejection
- corruption detection
- retained history
- automatic fallback to an older valid generation only when recovery is explicitly allowed
- damaged-generation evidence preservation
- interrupted-write residue safety
- repeated saves
- large-save round-trip
- explicit failure status

It also exposes generation-history and recovery APIs directly, matching the intended player-facing recovery UX.

## Why Enhanced Save System was not selected

Pinned candidate:
- commit: dc92d0bead1c449f36462f22e823b603e356e49a
- license: MIT

It passed ordinary save/load, module collection/application, deterministic battle resume, migration fixture, corruption detection, .bak manual recovery, and the large-save benchmark.

It failed architecture-critical requirements:
- future/newer schema was not rejected by the built-in format migration path
- no retained generation history comparable to SaveState
- no automatic older-generation recovery path
- schema migration is more tightly coupled to SaveWriter.FORMAT_VERSION and module migration than desired for project-owned business schema evolution

Its performance was substantially better in the extreme benchmark, but that does not override the project's fail-closed and recoverability requirements.

## Performance guardrail

Extreme CI fixture:
- 8 characters
- 120 world flags
- 120 locations
- 500 EventHistory
- 1000 inventory stacks

SaveState Lite:
- 405,806 bytes
- save: ~268 ms
- load: ~251 ms

Because Lite uses synchronous writes:
- save only at safe domain commit boundaries
- never save mid-EventCommand transaction
- never save every frame
- do not trigger sync save directly from latency-sensitive card input
- use transition/result screens or other non-sensitive moments for heavy autosaves
- re-benchmark when real production state approaches the extreme fixture

## Autosave boundaries

Approved examples:
- expedition start
- node settlement
- battle end
- safe turn boundary
- extraction settlement
- major fortress upgrade
- character reconstruction
- committed main-story event

Do not autosave while a transactional domain operation is only partially applied.

## Recovery UX contract

A corrupt newest generation must not silently become New Game.

The runtime should surface an explicit state such as:
- latest save is damaged
- older valid generation is available
- show its cycle/time metadata
- preserve the damaged generation
- let the user explicitly recover

If no valid generation exists, loading fails closed with a clear error.

## Final evidence

Run: 36283764675
Artifact:
- p0-6-save-results
- ID 10919349183
- SHA256 7723d444c5df28fc567d3fb364be0a35a125df25d508c73aabbc642df48f95d5

P0-6 technical decision complete.
