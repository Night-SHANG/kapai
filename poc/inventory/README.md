# P0-4 — Inventory

Goal: compare pinned GLoot 3.0.2 against a deliberately thin project-owned Inventory domain.

Authoritative static item data stays outside GLoot. fixtures/yard_item_export.json represents the P0 export contract from the YARD-owned ItemDefinition layer. scripts/build_gloot_bridge.py deterministically generates the GLoot prototree and a source-hash manifest. Generated output is never edited by hand.

Automated contract:
- I1 stack: 120 scrap -> 99 + 21
- I2 split: 99 -> 59 + 40
- I3 merge: 59 + 40 -> 99
- I4 weight consistency
- I5 hard weight limit is fail-closed
- I6 warehouse -> expedition transfer is atomic
- I7 key items cannot be discarded and are protected on emergency extraction
- I8 module-slot tag validation
- I9 100+ stack save round-trip
- I10 missing definition fails closed before state mutation
- emergency extraction keeps secure/key items, honors selected carry weight, and reports losses
- GLoot smoke validates real 3.0.2 stack/split/merge, WeightConstraint, source-ID bridge and serialization

The P0 does not lock secure-storage numeric values or final inventory UI. Human/editor UX remains a separate observation after the automated comparison.
