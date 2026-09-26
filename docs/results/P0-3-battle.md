# P0-3 Three-character Card Battle

Status: AUTOMATED TECHNICAL BASELINE COMPLETE / HUMAN + INPUT + PRESENTATION SMOKE PENDING

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

## Phase C — Formation + Sync

Final automated run:
GitHub Actions 36255956059 — SUCCESS

Technical fixture:
- draw model: per_character_quota
- action model: 3 Card Plays
- preferred-position card bonus: +2
- position threat cost scales with distance from required position
- Sync triggers only: Mark consume / Intercept / Link
- 1000 runs × 12 turns
- deterministic replay

### Free arbitrary adjustment

- formation needs: 4482
- adjustments: 4476
- fully resolved: 4476
- resolution rate: 99.8661%
- avg cards played: 3.0
- natural Sync total: 3093
- Sync per 3 turns: 0.77325
- explicit Sync-farm opportunity: 3.5833%
- utility sacrificed per extra farmed Sync: 1.67338

Interpretation:
This nearly erases formation pressure. If any character can freely jump to any slot every turn, position mostly becomes a reversible optimization rather than a meaningful constraint.

### Free adjacent adjustment

- formation needs: 4452
- adjustments attempted: 4445
- fully resolved: 2908
- full-resolution rate: 65.3190%
- avg cards played: 3.0
- natural Sync total: 2900
- Sync per 3 turns: 0.725
- explicit Sync-farm opportunity: 3.7417%
- utility sacrificed per extra farmed Sync: 1.65957

Interpretation:
This preserves the full 3 Card Plays while leaving a meaningful amount of unresolved position pressure. A front-to-rear relocation can require more than one turn, so formation is not an unlimited free teleport.

### Formation costs 1 Card Play

- formation needs: 4452
- adjustments/resolutions: 1406
- resolution rate: 31.5813%
- avg cards played: 2.88283
- action costs paid: 1406
- natural Sync total: 3397
- Sync per 3 turns: 0.84925
- deterministic replay: PASS

Sensitivity sweep:
- low threat values: essentially no paid movement
- medium threat values: partial movement response
- high threat values: abrupt heavy movement response and lower card throughput

Interpretation:
Charging a full Card Play makes movement highly sensitive to tuning thresholds and directly competes with the main card decision layer.

## Phase C technical baseline

SELECT:
one free adjacent Formation Adjustment per turn.

Do not use:
- unlimited arbitrary free swap
- ordinary formation move costing one Card Play

Future exception:
Sync/Command may buy an additional or stronger emergency formation adjustment.

## Sync result

The restricted three-trigger model produced about 0.725 natural Sync per 3 turns under the selected adjacent-move model.

Dedicated Sync-farm opportunities occurred on only ~3.74% of turns, and taking the extra Sync sacrificed ~1.66 utility on average.

This supports the intended role:
Sync should emerge from already-useful cross-character cooperation rather than become a second basic energy meter that players farm every turn.

## Automated P0-3 technical baseline

- Draw: independent per-character Draw/Discard
- Equipped cards: 8 per character
- Hand quota: 2 per character
- Visible combined hand: 6
- Retain unused cards
- Redraw: same-character replacement
- Normal action economy: 3 Card Plays
- Rare Heavy exception may cost 2 Plays
- Formation: 1 free adjacent adjustment per turn
- Sync: advanced team resource from meaningful cross-character triggers
- Battle domain remains deterministic/headless-authoritative

## Phase D — integrated BattleState / BattleCommand deterministic smoke

Final workflow:
GitHub Actions 36256390743 — SUCCESS

The selected Phase A/B/C rules were installed into one pure headless battle state and executed for 12 turns.

Validated:
- 12 completed turns
- 57 BattleCommands
- 57 state hashes checked command-by-command
- 58 invariant checks
- deterministic replay: PASS
- visible enemy Intent before player actions
- hand quota never exceeded 2 per character
- Card Plays stayed within 0..3
- Redraw stayed within 0..2
- formation always contained exactly the three unique characters
- Sync never dropped below zero
- one free adjacent formation adjustment per turn
- additional adjacent adjustment can spend 1 Sync

Final run state:
- Sync generated: 3
- Sync spent: 2
- final Sync: 1
- enemy HP: 18
- final formation: Bastion / Loom / Falcon
- final Intent: heavy attack -> Falcon, damage 5

RNG stream isolation:
- ordinary redraw from an already shuffled pile did not touch enemy_ai
- explicit shuffle advanced battle_draw and did not touch enemy_ai
- Intent generation advanced enemy_ai and did not touch battle_draw

This corrects an earlier failed probe that incorrectly assumed every draw must advance draw RNG. Drawing from a pre-shuffled pile by pop_back is deterministic and does not require new randomness.

Artifact:
- Run 36256390743
- Artifact ID 10910931337
- contains Phase A/B/C/D summaries

## Technical P0-3 conclusion

The automated battle core is technically closed around:

- per-character independent Draw/Discard
- 2-card quota each / combined 6-card visible hand
- same-character Redraw
- unused-card Retain
- 3 Card Plays
- rare explicit Heavy = 2 Plays
- one free adjacent Formation Adjustment per turn
- extra formation adjustment may spend Sync
- Sync generated by meaningful cross-character cooperation
- visible Intent
- separate battle_draw / enemy_ai RNG streams
- pure BattleState + BattleCommand replay boundary

See:
docs/decisions/battle-rules-decision.md

## Still pending before full P0-3 closure

Automated architecture testing cannot establish fun, readability or input quality.

Required later smoke:
- human short battles / Elite / Boss-like sessions
- keyboard navigation
- controller navigation
- mouse selection/targeting
- CardSelectionController -> BattleCommand input path
- Card Framework presentation-only integration
- scene-level visual/readability smoke

These do not invalidate the automated technical baseline, but P0-3 should not be marked fully complete until they are exercised.