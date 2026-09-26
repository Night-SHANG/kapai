# Inventory Domain Decision

Status: TECHNICAL DECISION COMPLETE

Engine baseline: Godot 4.7.1 stable.

## Selected

Lightweight project-owned Inventory domain.

YARD remains the sole primary authority for static item definitions. Runtime inventory state stores only stable item IDs, counts, optional instance data, slot state, and secure-state data. Static properties such as weight, max stack, key-item flags, and slot tags are resolved from YARD-derived definitions by item_id.

GLoot 3.0.2 is not selected as the production runtime inventory domain.

## Evidence

GitHub Actions:
- workflow: P0 Inventory
- successful run: 36261935089
- commit: 21c7a270630136e6fc28f043c89311326fcb1d2b
- engine: Godot 4.7.1 stable
- artifact: p0-4-inventory-results, ID 10912132635

Lightweight domain:
- I1-I10 PASS
- add/split/merge PASS
- exact weight accounting PASS
- hard weight-limit rejection PASS
- atomic transfer PASS
- key-item protection PASS
- module-slot tag validation PASS
- 120-stack save/load round-trip PASS
- removed-definition fail-closed behavior PASS
- emergency extraction contract PASS

GLoot 3.0.2:
- pinned commit ce88b7adc7b952b4df8ebe4836339de334d0d0cc
- MIT
- YARD -> generated prototree bridge PASS
- split/merge PASS
- WeightConstraint PASS
- hard-limit rejection PASS
- serialize/deserialize PASS

## Why GLoot is not selected

GLoot works technically, but it does not remove enough project-specific runtime work to justify becoming the inventory domain.

The P0 exposed a required project-owned layer for:
- YARD -> GLoot generated prototype bridge and source-hash validation
- business quantity -> legal max-stack normalization
- key-item policy
- secure storage
- module-slot tag policy
- emergency extraction selection/loss rules
- definition migration / missing-definition handling

The first failed run was useful evidence rather than a GLoot defect: `add_item_autosplitmerge()` does not mean "normalize an arbitrary business quantity into max-stack chunks". A project adapter is required before handing such quantities to GLoot.

That leaves the project maintaining both a generated GLoot representation and a meaningful business-policy wrapper, while the actual inventory requirements remain small.

## Why the lightweight domain is selected

The project-owned model covers the actual domain directly:
- `ItemStack`
- `InventoryState`
- add/remove/split/merge
- deterministic weight calculation
- hard capacity validation
- atomic transfer
- key-item rules
- secure-state handling
- module-slot rules
- emergency extraction
- save/migration boundary

It keeps one content authority, makes save migration explicit, and keeps failure behavior easy to audit and regression-test.

## Production boundary

The lightweight inventory domain owns business state and rules.

Presentation must not mutate inventory state directly.

All external/UI commands should go through explicit inventory operations or commands so atomicity and validation remain testable.

YARD is the content authority. No second hand-authored item database is allowed.

## GLoot disposition

GLoot is rejected as the runtime domain for the current project scope, not rejected as a library in general.

If the project later requires materially richer inventory presentation or rules such as grid/Tetris placement, complex equipment topology, or a much broader editor-driven inventory feature set, GLoot may be re-evaluated as a presentation/helper layer or as a new domain candidate.

## Remaining non-blocking work

- Human/editor UX observation is not required to reverse the runtime-domain decision.
- Exact secure-storage capacity values remain a gameplay/balance decision.
- Exit-time Godot warnings from the isolated smoke (ObjectDB/resource cleanup) remain technical debt in the P0 harness, not a functional inventory failure.
