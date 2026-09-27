# Third-party dependencies

The formal dependency identity is now recorded in `third_party/dependencies.lock.json`.

P0 comparison addons are still installed on demand inside isolated PoC projects and are not automatically production dependencies.

## Production-facing baseline

Runtime:
- YARD v1.2.0 @ 48a518b4bec03c8b5ad446f57a2b669110a1752b — MIT — static Definition registry
- Card Framework v1.4.0 @ a74b713863adb27a22965a8e6ed039d0c4016791 — MIT — presentation only; provisional until P0-3 Human Playtest
- Dialogue Manager v4.1.0 @ a719088aea342572f29b5559fd8726896c9519b2 — MIT — narrative/presentation only
- SaveState Lite v2.0.0 @ 22b912aebbc6b52b3b31f74d3d83fec48b53870c — MIT — save I/O/generation/recovery only

Development:
- GdUnit4 v6.2.1 @ 08ffc7c65b61b1b2edd545616061a99973c13ce1 — MIT

Engine:
- Godot 4.7.1 stable / official build 4.7.1.stable.official.a13da4feb

## Project-owned instead of external runtime frameworks

- DefinitionRegistry adapter
- EffectRuntime
- Battle Domain
- Inventory Domain
- World/Fortress/Character state
- Event Domain
- Save DTO/schema/migrations
- RNG service

## P0 reference-only candidates

These were evaluated but are not production runtime dependencies:
- Godot DataTables
- GodotGAS
- GLoot
- Enhanced Save System
- FlowKit

Do not reintroduce one of these into the production addon set without a new architecture decision and affected regression tests.

## Version rule

No floating `main`.

Changing a locked dependency requires:
1. dedicated branch/PR
2. license recheck
3. affected GdUnit/Preflight suites
4. save migration regression when persistence is affected
5. manifest update only after validation

## License handling

All currently locked external plugins are MIT at the pinned references and their upstream license file paths are recorded in the manifest.

Before public distribution:
- retain the required copyright/license notices
- generate a complete Third-Party Notices file from the actual packaged dependency set
- recheck any optional dependencies adopted after this baseline
