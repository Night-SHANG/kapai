# P0-6 Save / Restore / Migration

Purpose: compare SaveState Lite 2.0.0 against Enhanced Save System on the fixed Godot 4.7.1 baseline using the same project-owned Save DTO contract.

Hard rules:
- Project owns Save Schema and migrations.
- Save DTO contains primitives / arrays / dictionaries / stable IDs only.
- Node / Scene / plugin runtime references are forbidden.
- Corruption, unsupported newer schema, migration failure, and missing critical definitions must fail closed.
- Failed load must never silently become New Game.
- Recovery must preserve the damaged evidence.
- Mid-expedition and battle-turn-boundary state must restore deterministic continuation.
- Cross-domain settlement must commit atomically.

Candidates:
- SaveState Lite v2.0.0 / 22b912aebbc6b52b3b31f74d3d83fec48b53870c / MIT.
- Enhanced Save System / dc92d0bead1c449f36462f22e823b603e356e49a / MIT.
- GdUnit4 v6.2.1 / 08ffc7c65b61b1b2edd545616061a99973c13ce1 / MIT.

The two candidates live in isolated Godot projects to avoid addon global-class collisions.
