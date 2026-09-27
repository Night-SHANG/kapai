# P0-6 Save / Restore / Migration

Status: PASS — TECHNICAL DECISION COMPLETE

Engine baseline: Godot 4.7.1 stable / Windows x64.

## Candidates pinned at P0-6 start

### SaveState Lite
- release: v2.0.0
- commit: 22b912aebbc6b52b3b31f74d3d83fec48b53870c
- MIT
- upstream release date: 2026-09-24

### Enhanced Save System
- no formal GitHub release at P0-6 start
- pinned main commit: dc92d0bead1c449f36462f22e823b603e356e49a
- MIT
- GDScript implementation used

### Test framework
- GdUnit4 v6.2.1
- commit: 08ffc7c65b61b1b2edd545616061a99973c13ce1
- MIT

## Fixed Save DTO

The test fixtures use the already-approved project state boundaries:
- profile metadata
- WorldState
- FortressState
- 8 CharacterState entries
- ResearchState
- lightweight InventoryState
- EventHistory
- TutorialState
- ExpeditionState (Threat 58)
- BattleState at turn 7
- 5 independent RNG streams
- migration metadata

No Node, Scene instance, Object reference, plugin runtime object, or resource path is a business key.

## Automated matrix

Both candidates are tested against the same semantic requirements:
- current schema round-trip
- expedition resume
- battle boundary + deterministic next command
- v1 -> v2 -> v3 migration
- direct v1 -> v3 ordered migration
- stable-ID alias migration
- missing critical ID failure
- newer schema rejection
- interrupted-write residue
- corruption detection
- backup / retained-history recovery
- evidence preservation
- repeated saves
- 8 characters / 100+ flags / 100+ locations / 500+ EventHistory / 1000 stacks benchmark

## Final result

Final GitHub Actions run:
- workflow: P0 Save
- run: 36283764675
- commit: 5802f98bdd796aee6161da9fcac41c6cc81ab5c5
- result: success
- artifact: p0-6-save-results
- artifact ID: 10919349183
- artifact SHA256: 7723d444c5df28fc567d3fb364be0a35a125df25d508c73aabbc642df48f95d5

### SaveState Lite v2.0.0

Hard requirements: PASS.

Validated:
- Godot 4.7.1 stable
- current schema round-trip
- mid-expedition restore
- battle turn-boundary deterministic resume
- project-owned ordered schema migration
- stable-ID alias migration
- missing critical ID fail-closed
- newer schema rejection
- corruption detection
- retained immutable generation history
- automatic recovery from an older valid generation
- damaged-generation evidence preservation
- interrupted-write residue safety
- repeated saves
- large-save round-trip
- explicit failure status
- recovery history API

Extreme benchmark fixture:
- 8 characters
- 120 world flags
- 120 locations
- 500 EventHistory entries
- 1000 Inventory stacks
- file size: 405,806 bytes
- save: 267,972 µs
- load: 251,122 µs

The Lite backend is synchronous. This is acceptable only with the already-defined safe save boundaries; it must not be invoked in the middle of EventCommand transactions, every frame, or on latency-sensitive combat input.

### Enhanced Save System

Hard requirements: FAIL.

Validated:
- ordinary round-trip
- expedition restore
- deterministic battle resume
- migration fixture
- missing-ID fail-closed
- corruption detection
- explicit read_failed reason
- atomic tmp behavior
- .bak manual recovery
- repeated saves
- large-save round-trip

Blocking differences:
- newer-schema rejection: FAIL. A format version newer than the current SaveWriter format is not rejected by the built-in migration path.
- retained generation history: absent.
- automatic older-generation recovery: absent.
- business schema evolution is more coupled to the plugin's SaveWriter.FORMAT_VERSION / module migration model than desired.

Extreme benchmark fixture:
- file size: 90,045 bytes
- save: 7,138 µs
- load: 5,540 µs

Enhanced is materially faster/smaller in this benchmark, but the project prioritizes recoverability, explicit schema ownership, and fail-closed compatibility over raw save throughput.

## Decision

Select **SaveState Lite v2.0.0** as the production save I/O / generation / recovery layer.

Project-owned responsibilities remain outside the plugin:
- Save DTO schema
- schema_version
- ordered migrations
- stable-ID aliases / removal policy
- Registry re-resolution after load
- autosave commit boundaries
- gameplay state validation
- recovery UX wording

SaveState is not allowed to become a gameplay-domain authority. It persists and recovers project-owned DTO state.

P0-6 technical decision complete.
