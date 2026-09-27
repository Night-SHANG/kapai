# AI-native Execution Rules

Status: ACTIVE

The project does not use human staffing limits as artificial engineering limits.

## Batch boundary

Work is divided by:
- dependency order
- architecture boundaries
- risk
- verifiability

It is not divided by assumptions such as one engineer-day, one small ticket, or one tiny change per review.

## Default execution

When architecture and interfaces are already decided, prefer one coherent batch that includes:
- implementation
- data/schema changes
- tests
- Preflight
- migration rules
- docs
- CI wiring

Then audit the whole batch.

## Avoid duplicate temporary work

Do not create a throwaway MVP/prototype merely because traditional teams often do.

A standalone PoC is justified only when:
- technical feasibility is genuinely unknown
- alternatives need real comparison
- a wrong choice would cause major structural rework
- formal implementation cannot safely provide the validation surface

If production implementation can cheaply carry the validation, validate there.

Example: P0-3 Human Playtest is now embedded in the production Battle Scene / Dev Battle Lab rather than getting a separate temporary game build.

## Human checkpoints

Ask for human judgment primarily when automation cannot settle the question:
- gameplay feel/fun
- visual preference
- real hardware/driver behavior
- local account/device permissions
- subjective copy/audio feel

Do not stop after every small implementation unit just to imitate a traditional review cadence.

## Quality remains mandatory

AI-native speed does not remove:
- license checks
- deterministic tests
- migration safety
- Fail Closed behavior
- Preflight
- CI
- traceable commits

The intended pattern is:

large coherent implementation -> broad automated validation -> small number of meaningful human checks.
