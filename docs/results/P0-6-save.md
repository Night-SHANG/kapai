# P0-6 Save / Restore / Migration

Status: IMPLEMENTED — CI RESULT PENDING

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

## Candidate-specific observation to verify

SaveState Lite exposes retained immutable generations and explicit recovery APIs. Enhanced Save System exposes atomic .tmp + optional .bak, module-based collection/application, and migration around its save-format version.

P0 must determine whether Enhanced's module model satisfies project-owned schema evolution and Fail Closed requirements without binding business schema to plugin file-format version.

No final winner is recorded until GitHub Actions on Godot 4.7.1 is inspected.
