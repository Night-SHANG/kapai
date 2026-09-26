# Data Layer Decision

Decision: YARD

Status: Selected after P0-1 automated technical validation.

Engine baseline: Godot 4.7.1 stable.

Pinned candidate:
- YARD v1.2.0
- commit 48a518b4bec03c8b5ad446f57a2b669110a1752b
- MIT

Rejected as primary authority:
- Godot DataTables v1.0.1
- commit f405b187b013e3914b812db201f014ac946335a3
- MIT

## Why YARD

The project's content model is entity-centric rather than spreadsheet-centric.

Cards, enemies, items, characters, locations and events benefit from:

- stable human-readable IDs
- independent Resource files
- low Git conflict radius
- direct Codex/AI file targeting
- Godot-native Resource references
- future content-pack/mod friendliness
- easy takeover if the registry plugin disappears

P0 verified that a YARD stable ID continued loading the correct card after the .tres file was physically moved to another directory.

## Why not DataTables as primary

DataTables worked correctly for:
- 100-row save/load
- additive schema changes
- different-row Git merges
- JSON round-trip
- CSV round-trip

It also clearly wins bulk scalar editing.

However:
- all rows are concentrated into a table resource
- DataStructure.row_id is empty after save/reload in v1.0.1
- runtime content becomes more coupled to table/row framework concepts
- our game benefits more from entity file isolation than from making the table itself the source of truth

Its useful idea is retained:

Build a verified CSV/JSON balancing bridge around YARD later.

## Required adapter boundary

Game domain code should depend on our own DefinitionRegistry interface, not directly on YARD everywhere.

Expected operations:
- has(id)
- load(id)
- list_ids()
- filter/query where justified
- validate references

This preserves replacement freedom.

## CI rule learned during P0-1

Godot process exit code alone is not enough.

Windows Preflight must:
- explicitly wait for Godot process completion
- capture stdout/stderr
- reject SCRIPT ERROR / Parse Error / failed script loading
- then check process exit code

Headless automation must avoid depending on editor-only UI internals unless specifically under an editor-UI test.

## Pending but non-blocking

A local Godot 4.7.1 GUI editor smoke and optional real Codex content-edit smoke remain before mass content production.
