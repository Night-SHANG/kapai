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

## Phase B — action economy

Run #3: GitHub Actions 36255243466 — SUCCESS

Draw model fixed to:
per_character_quota

Both models used the same 24-card cost/utility fixture and deterministic seeds.

### 3 Card Plays

- turns: 12000
- avg cards played: 2.63225
- budget utilization: 100%
- fragment turn rate: 0%
- filler turn rate: 14.2667%
- high-cost retained rate: 27.0667%
- all-three-role participation: 47.9417%
- one-role-only rate: 3.4667%
- role absence events: 6663
- deterministic replay: PASS

### Shared 4 AP

- turns: 12000
- avg cards played: 2.96267
- budget utilization: 100%
- fragment turn rate: 0%
- filler turn rate: 66.0583%
- high-cost retained rate: 93.225%
- all-three-role participation: 36.9083%
- one-role-only rate: 1.55%
- role absence events: 7757
- deterministic replay: PASS

## Phase B interpretation

The tested AP fixture did not produce unused-AP fragmentation. Therefore AP fragmentation is not evidence against the AP model in this experiment.

Shared 4 AP did play slightly more cards per turn and had fewer one-role-only turns.

However it also:
- reduced full three-role participation
- greatly increased low-value filler plays
- retained 2-cost cards in hand on most turns
- required cost values on all cards instead of only rare heavy exceptions

This suggests the AP layer is consuming design space and encouraging arithmetic optimization without providing enough additional tactical benefit in the current battle model.

## Phase B technical winner

3 Card Plays

This remains a technical P0 result, not a claim that the system is already fun.

Phase C next:
- 1 free Formation Adjustment vs formation costing 1 Card Play
- Sync generation using Mark consume, Intercept and Link
- deterministic replay

The final production battle rule still requires later human playtest.
