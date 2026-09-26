# P0-5 World Event Pipeline

Purpose: validate the already-approved discrete event architecture on Godot 4.7.1 stable.

Authoritative chain:

LocationState -> EventSelector -> YARD EventDefinition -> ConditionEvaluator -> available Option IDs -> Dialogue Manager presentation -> selected option_id -> EventResolver -> EventCommands -> WorldState / ExpeditionState / Inventory -> save boundary.

Rules:

- YARD is the static Definition authority.
- The lightweight project-owned Inventory model is represented by stable item_id/count state.
- Dialogue Manager is presentation only. Event dialogue files are rejected by Preflight if they contain gameplay mutations.
- UI/presentation never mutates WorldState directly.
- Resolver applies commands atomically against a draft state and commits only when the whole command set succeeds.
- Preview is derived from the same command data.
- P0 code is disposable; the contracts and regression tests are not.

Fixtures:

- event_test_sealed_lab: FTL-style special options.
- event_test_lab_alarm: StartBattle plus win/retreat/wipe continuation.
- event_test_scavenger_ping: repeat/cooldown history.

Run:

PowerShell:
.\run_p0.ps1 -GodotExe "<Godot_v4.7.1-stable_win64.exe>"
