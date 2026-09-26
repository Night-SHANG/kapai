# P0-5 World Event Pipeline

Status: IMPLEMENTED — CI RESULT PENDING

Engine baseline: Godot 4.7.1 stable / Windows x64.

## Existing decisions reused

P0-5 does not reopen earlier decisions:

- YARD v1.2.0 remains the static Definition authority.
- Lightweight project-owned Inventory remains the runtime item-state model.
- Dialogue Manager is narrative/presentation only.
- WorldState remains the permanent world authority.
- UI returns option_id and never writes permanent gameplay state directly.

## Pinned dependencies

- YARD v1.2.0
  - commit 48a518b4bec03c8b5ad446f57a2b669110a1752b
  - MIT
- Dialogue Manager v4.1.0
  - commit a719088aea342572f29b5559fd8726896c9519b2
  - MIT
  - latest stable release checked at P0-5 start; release targets Godot 4.7
- GdUnit4 v6.2.1
  - commit 08ffc7c65b61b1b2edd545616061a99973c13ce1
  - MIT

## Implemented acceptance surface

- YARD EventDefinition resources + stable-ID registry.
- Location/EventDefinition/Condition/Option/Command/WorldState chain.
- Condition base set:
  - HasCharacter
  - PartyHasTag
  - HasItem
  - ItemCountAtLeast
  - HasResearch
  - ResourceAtLeast
  - ThreatRange
  - LocationState
  - WorldFlag
  - EventSeen / EventNotSeen
  - ALL / ANY / NOT
- Command base set:
  - Add/RemoveResource
  - Add/RemoveItem
  - ChangeThreat
  - SetWorldFlag
  - SetLocationState
  - DiscoverLocation
  - UnlockRoute
  - DamageCharacter
  - ApplyInjury
  - StartBattle
  - RestoreFacility
  - UnlockArchive
- Transactional command application.
- Preview derived from the same command data.
- Once and cooldown EventHistory.
- BattleResult continuation for win / retreat / wipe.
- JSON round-trip at committed state boundary.
- Static reference/localization/dialogue-cue validation.
- Static critical-event reachability guard.
- Dialogue mutation ban for P0 event dialogue.
- Real Dialogue Manager cue resolution and option_id-only return bridge.
- GdUnit4 domain tests.
- Headless integration smoke.

## Fixed content

The P0 reuses the pre-agreed sealed-laboratory fixture rather than inventing new gameplay:

- force
- breach
- engineering
- research_auth
- leave

Additional fixtures exist only to test battle continuation and cooldown history.

## Decision discipline

No final P0-5 architecture verdict is recorded until the GitHub Actions run is inspected.

A passing run must prove that the complete pipeline can execute without Dialogue UI and that enabling real Dialogue Manager does not move gameplay authority into dialogue files.
