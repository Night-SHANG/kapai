# P0-4 Inventory

Status: READY TO RUN — AUTOMATED GLOOT 3.0.2 VS LIGHTWEIGHT DOMAIN COMPARISON

Engine: Godot 4.7.1 stable / Windows x64

## Candidates

### A — GLoot 3.0.2 + generated bridge
- upstream: peter-kish/gloot
- tag: v3.0.2
- commit: ce88b7adc7b952b4df8ebe4836339de334d0d0cc
- license: MIT
- YARD remains the intended static item authority.
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

## Automated acceptance contract

I1–I10 from Notion 24.10 are encoded in poc/inventory/scripts/p0_inventory_smoke.gd.

The same run also exercises real GLoot 3.0.2 for:
- generated prototype bridge
- stack autosplit
- split/merge
- WeightConstraint
- hard-limit rejection
- serialize/deserialize round-trip

## Decision discipline

Do not select a winner before the workflow result is inspected.

The automated result should answer whether GLoot materially reduces the difficult runtime work after accounting for the bridge and project-specific policy layer. Human/editor UX is a separate observation and is not fabricated by CI.
