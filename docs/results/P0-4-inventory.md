# P0-4 Inventory

Status: AUTOMATED COMPARISON COMPLETE — TECHNICAL DECISION COMPLETE

Engine: Godot 4.7.1 stable / Windows x64

## Decision

Selected: lightweight project-owned Inventory domain.

Rejected as production runtime domain: GLoot 3.0.2 + generated YARD bridge.

See `docs/decisions/inventory-decision.md`.

## Candidates

### A — GLoot 3.0.2 + generated bridge
- upstream: peter-kish/gloot
- tag: v3.0.2
- commit: ce88b7adc7b952b4df8ebe4836339de334d0d0cc
- license: MIT
- YARD remains the static item authority.
- P0 bridge generates GLoot prototree JSON from the canonical item-export fixture and records a source SHA-256 manifest.
- No hand-maintained second item database is allowed.

### B — lightweight project-owned domain
Minimal responsibilities:
- ItemStack
- InventoryState
- add/remove/split/merge
- hard weight limit
- atomic transfer
- key-item rule
- module slot tags
- secure state
- emergency extraction selection
- save round-trip
- missing-definition fail-closed migration boundary

## Run evidence

### Run #1 — failure used to correct the integration assumption
- Run ID: 36261343487
- commit: 05c94ad23523a305caba96051b09c18ae842958c
- result: failure
- Godot 4.7.1 PASS
- pinned GLoot dependency PASS
- YARD -> GLoot bridge PASS
- failure: expected 120 scrap to become 99 + 21 through `add_item_autosplitmerge()`

Upstream v3.0.2 source/tests confirmed that GLoot autosplit behavior is driven by inventory constraint space and does not normalize an arbitrary business quantity beyond a prototype's max-stack size. The P0 was corrected to include a thin quantity adapter.

### Run #2 — success
- Run ID: 36261935089
- commit: 21c7a270630136e6fc28f043c89311326fcb1d2b
- result: success
- artifact: p0-4-inventory-results
- artifact ID: 10912132635
- artifact SHA-256: 900bcb80ef349df7b8486d1a9a07d922642fcc3b448dd4bd8fac56dd4e5c6d89

Lightweight:
- I1-I10: PASS
- atomic transfer: PASS
- 120-stack save/load round-trip: PASS
- missing-definition fail closed: PASS
- emergency extraction: PASS
- extraction sample: 2 auto-protected, 12 kept, 20 lost, selected weight 1.0

GLoot:
- YARD source bridge: PASS
- quantity adapter required: yes
- split/merge: PASS
- WeightConstraint: PASS
- serialization round-trip: PASS
- application-specific wrapper still required for:
  - quantity/max-stack normalization
  - key-item policy
  - secure storage
  - module-slot tags
  - emergency extraction
  - definition migration

## Technical conclusion

Both candidates can execute the basic inventory mechanics.

The deciding factor is ownership complexity: after integrating GLoot, the project still needs a generated secondary representation plus a project-owned wrapper for most rules that are actually specific to this game. The lightweight domain already passed those project-specific contracts directly and keeps YARD as the single content authority.

Therefore P0-4 selects the lightweight project-owned Inventory domain.

## Non-blocking notes

Godot reported 13 leaked ObjectDB instances and 1 resource still in use at smoke-process exit. The workflow still completed successfully. Treat these as isolated P0 harness cleanup debt, not as an inventory functional failure.
