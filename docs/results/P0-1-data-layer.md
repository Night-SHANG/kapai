# P0-1 Data Layer Result

Status: TECHNICAL DECISION COMPLETE — YARD SELECTED / LOCAL EDITOR UX SMOKE PENDING

## Environment

- Godot: 4.7.1 stable / Windows x64
- YARD: v1.2.0 @ 48a518b4bec03c8b5ad446f57a2b669110a1752b
- DataTables: v1.0.1 @ f405b187b013e3914b812db201f014ac946335a3
- GdUnit4: v6.2.1 @ 08ffc7c65b61b1b2edd545616061a99973c13ce1

## CI validation history

- Run #1: failed — PowerShell version capture bug.
- Run #2: false positive — Godot parse errors were not treated as failure.
- Run #3: failed — YARD editor-only AnyIcon crashed headless Godot.
- Run #4: failed — script-created resources had no persisted Resource UID.
- Run #5: success — first trustworthy bootstrap pass.
- Run #6: failed — our DataTables serialization analyzer matched row_order instead of rows map.
- Run #7: success — Git/diff/merge format analysis passed.
- Run #8: success — move/schema/IO/migration-out probes passed.

## Core bootstrap

- [x] Exact Godot 4.7.1 stable check
- [x] Deterministic fixture generation
- [x] Pinned dependency install by tag + commit
- [x] YARD 100 independent CardDefinition resources
- [x] Explicit persistent Resource UIDs
- [x] YARD 100-entry stable Registry
- [x] YARD runtime headless preflight
- [x] DataTables 100-row table
- [x] DataTables save/reload preflight
- [x] Fail-closed CI script error detection

## Stable IDs and file moves

### YARD

PASS.

Physical file move:

card_bastion_000.tres
-> data/cards/moved/card_bastion_000.tres

After an Editor filesystem/import scan, the original stable ID:

card_bastion_000

still resolved through the original Resource UID and loaded the moved resource.

Observed path:

res://data/cards/moved/card_bastion_000.tres

This directly validates the core stable-ID + UID design.

### DataTables

Row stable IDs remain dictionary keys and row_order values after save/reload.

However DataStructure.row_id itself becomes empty after reload in v1.0.1.

This does not destroy the table key, but it means a Row object cannot reliably assume its own row_id field has been rehydrated.

## Git diff / merge

Fixture: 100 cards.

### YARD

- 100 independent .tres entity files
- ~1100 total lines
- ~11 lines/entity
- Branch A edited card_bastion_000
- Branch B edited card_falcon_001
- Merge: PASS, no conflict

### DataTables

- 1 centralized cards_table.tres
- ~914 total lines
- ~9.14 lines/entity-equivalent
- Branch A edited one Row
- Branch B edited another Row
- Merge: PASS, no conflict

Conclusion:

Do not claim that DataTables always conflicts. Git can merge changes to separate serialized Row subresources cleanly.

YARD still has the stronger isolation boundary because unrelated entities are different files.

## Batch balancing

Structural 30-card edit:

- YARD: 30 content files touched
- DataTables: 1 table file touched

Clear DataTables advantage.

Decision consequence:

Do not adopt a second primary database just for bulk balancing. If YARD is selected, later provide a verified CSV balance export/import tool for selected scalar fields.

## Schema evolution

Additive schema test on old serialized data:

Added:

schema_probe: int = 7

without rebuilding existing content.

### YARD

PASS:
- old base_value stayed 3
- new schema_probe read 7

### DataTables

PASS:
- old base_value stayed 3
- new schema_probe read 7
- sanitize/save remained valid

Conclusion:

Both candidates handle common additive schema evolution adequately.

Destructive rename/removal still requires explicit migration policy in either design and must not be treated as automatic.

## External table / migration round-trip

### DataTables

PASS:
- JSON export 100 rows
- JSON import 100 rows
- CSV export 100 rows
- CSV import 100 rows
- stable ID preserved
- owner_character_id preserved
- base_value preserved

This is a real DataTables strength.

### YARD

PASS:
- Registry exported 100 stable IDs plus ordinary content values to JSON.
- Demonstrates a straightforward migration-out path if YARD is ever replaced.

YARD content resources are ordinary Godot Resources using our own CardDefinition script; the plugin mainly owns registry/editor tooling rather than the entity payload format.

## Candidate-specific issues found

### YARD

1. Headless automation must not call editor_only RegistryIO directly.
   - Its AnyIcon static initialization can crash Godot 4.7.1 headless Editor.
   - Normal plugin import itself succeeded.
   - CI now builds the runtime Registry without editor-only UI internals.

2. Script-created .tres resources need explicit persistent UIDs.
   - Fixed by ResourceUID.create_id_for_path + ResourceSaver.set_uid.
   - This is now part of our data tooling contract.

### DataTables

1. DataStructure.row_id is empty after save/reload in v1.0.1.
   - Stable table dictionary key still exists.
   - Any runtime code depending on row.row_id would need an adapter/rehydration fix.

2. Fresh project import reports several invalid ext_resource UID warnings in plugin editor scenes and falls back to text paths.
   - Non-fatal in P0.
   - Adds packaging noise that should be tracked.

## Lock-in / takeover

### YARD

Low.

- Entity payloads are our own ordinary .tres Resources.
- Registry is a simple stable-ID <-> Resource UID mapping.
- 100 entries successfully exported to normal JSON.
- If upstream stops, the registry behavior is small enough to replace behind our own DefinitionRegistry interface.

### DataTables

Low to moderate.

- JSON/CSV migration path is excellent.
- Entity storage is coupled to DataTable/DataStructure/RowHandle concepts and generated schema workflow.
- Moving away is feasible because export is proven, but the live runtime model is more framework-shaped.

## Codex / AI editing assessment

No claim of a real Codex benchmark has been made yet.

Structural assessment:

YARD is easier for targeted automated edits because one content entity maps to one small Resource file.

DataTables is easier for large scalar/balance sweeps because one table contains many rows.

A real local Codex edit smoke remains optional before formal content production.

## Editor UX

Not fully validated interactively in CI.

Headless Editor initialization succeeds for both plugins.

Local Godot 4.7.1 GUI smoke remains:
- open/create/edit one entity
- rename/move one resource
- filter/search
- add 10 cards
- inspect long fields
- undo/redo

This is a non-blocking final UX check, not a reason to delay P0-2.

## Decision

SELECT YARD as the project's primary static content authority.

Reasons:

1. Stable string IDs + Resource UIDs survived actual physical file moves.
2. Each entity remains an independent Resource, matching Git and AI-assisted development.
3. Save files can reference business stable IDs instead of file paths.
4. Plugin takeover risk is low; payload resources remain ours.
5. Migration-out to plain JSON is proven.
6. Additive schema evolution passed.
7. DataTables' strongest advantage — CSV/table bulk editing — can be recreated as a one-way/validated balancing tool without introducing a second source of truth.
8. DataTables v1.0.1 has a real row_id rehydration issue after reload.

## Architecture consequence

Primary authority:

YARD Registry + ordinary typed Godot Resource Definitions.

Save:

stable business IDs only.

Runtime:

DefinitionRegistry adapter wraps YARD so game code does not scatter direct plugin calls.

Bulk balancing:

future CSV/JSON export/import tooling operates on YARD resources and validates before commit.

Never use YARD and DataTables as two simultaneous primary databases.

## Remaining non-blocking checks

- [ ] Local Godot 4.7.1 GUI editor UX smoke
- [ ] Optional real Codex targeted-edit smoke

These can be done before formal content production. P0-2 may proceed using YARD as the selected data layer.
