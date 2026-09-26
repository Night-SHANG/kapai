# P0-1 Data Layer Result

Status: CI BOOTSTRAP VERIFIED / FINAL DECISION PENDING

## Environment

- Godot: 4.7.1 stable / Windows x64
- YARD: v1.2.0 @ 48a518b4bec03c8b5ad446f57a2b669110a1752b
- DataTables: v1.0.1 @ f405b187b013e3914b812db201f014ac946335a3
- GdUnit4: v6.2.1 @ 08ffc7c65b61b1b2edd545616061a99973c13ce1

## Automated bootstrap

Run #5: GitHub Actions 36250009868 — SUCCESS

- [x] Exact engine version check
- [x] Deterministic fixture generation
- [x] YARD plugin install
- [x] DataTables plugin install
- [x] YARD 100 independent card resources
- [x] YARD stable registry
- [x] YARD headless preflight
- [x] DataTables 100-row table
- [x] DataTables headless preflight

## Important observations

### YARD
- Runtime Registry works on Godot 4.7.1.
- 100 independent CardDefinition resources load through stable string IDs.
- Headless automation must not depend on YARD editor-only RegistryIO because its icon/editor initialization can crash headless Godot 4.7.1.
- Script-generated resources require explicit persisted Resource UIDs.

### DataTables
- 100-row table saves and reloads successfully on Godot 4.7.1.
- row_order and stable StringName keys survive reload.
- Current v1.0.1 observation: DataStructure.row_id becomes empty after save/reload.
- This matches source audit: row_id is injected by add_row()/duplicate_row(), but row_id itself is not exported and DataTable has no visible reload rehydration pass.

## Experiments

### Stable ID / file moves
In progress.

### Git diff / merge
Automated format experiment added after Run #5. Pending CI result.

### Codex single-entity edit
Pending.

### Codex batch creation
Pending.

### Schema v1 -> v2 -> v3
Pending.

### Batch balance
Structural comparison automated after Run #5; final judgment pending.

### CSV/JSON round-trip
Pending.

### Runtime lookup/query
Bootstrap passed for both candidates.

### Editor UX
Pending local/editor validation.

### Plugin lock-in / migration-out
Pending final analysis.

## Decision

Not locked yet.

Current evidence still favors YARD for this project because its independent Resource model aligns better with stable IDs, Git isolation, Codex editing and future content packs. DataTables remains competitive for bulk table editing/CSV workflows, but the row_id rehydration issue is a real implementation concern that must be counted in the final decision.
