# P0-3 Three-character Card Battle

Status: PHASE A TECHNICAL WINNER — PER_CHARACTER_QUOTA / VERIFYING GREEN RUN

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

## Run #1 raw result

Workflow: 36254372345

The workflow ended as failure only because the first test treated shared-pool character absence as an invariant violation. The autosim itself completed and produced valid metrics.

### per_character_quota

- turns: 12000
- exact 2/2/2 rate: 1.0
- character absence events: 0
- 3+ same-character turns: 0
- average role-count imbalance: 0.0
- unique hand signatures: 9279
- deterministic replay: PASS

### shared_fair_pool

- turns: 12000
- exact 2/2/2 rate: 0.1115
- character absence events: 1344
- 3+ same-character turns: 9693
- average role-count imbalance: 1.99875
- guarantee searches: 12717
- guarantee cards skipped: 19654
- same-character redraw searches: 24000
- redraw cards skipped: 46364
- unique hand signatures: 11576
- deterministic replay: PASS

## Interpretation

Shared fair pool does provide more hand-combination variety:
11576 unique signatures vs 9279.

However it pays for that with substantial hidden intervention:
- guaranteed character searches
- skipped cards
- redraw searches
- altered effective draw order

Even with those interventions it still produced character-absence events after redraw/search interactions and frequently concentrated 3+ cards from one character.

This is a structural result, not a test harness crash.

## Phase A technical winner

per_character_quota

Reasons:
1. explicit rule: 2 cards per character
2. zero character absence in the autosim
3. no hidden deck search required
4. same-character redraw is natural
5. simpler deterministic replay semantics
6. clearer deck-building ownership
7. retains substantial hand variation without manipulating the shared draw order

The shared model's extra variety is noted as a benefit, but does not currently outweigh its intervention complexity and squad-participation instability.

## Next

Phase B will use per_character_quota and compare:
- 3 Card Plays
- shared 4 AP

No final battle decision until Phase B and later human playtest.
