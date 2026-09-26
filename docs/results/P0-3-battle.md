# P0-3 Three-character Card Battle

Status: PHASE A PENDING

Engine: Godot 4.7.1 stable / Windows x64

## Phase A — draw model

Common:
- 3 characters
- 8 cards each
- 6 visible cards
- 3 plays
- 2 redraws
- retain
- 12 turns/run
- 1000 runs/model
- deterministic seed

Candidates:
- per_character_quota
- shared_fair_pool

Metrics:
- exact 2/2/2 hand rate
- character absence
- 3+ same-character concentration
- average role-count imbalance
- forced guarantee searches
- cards skipped by guarantee search
- same-character redraw searches
- cards skipped by redraw search
- unique hand signatures
- deterministic replay

No final battle decision before Phase B and human playtest.
