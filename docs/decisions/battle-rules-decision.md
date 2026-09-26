# Battle Rules Technical Baseline

Status: Automated technical decision complete; human/input/presentation smoke pending.

Engine baseline: Godot 4.7.1 stable.

## Selected core model

- 3-character fixed squad
- 8 equipped cards per character
- independent per-character Draw / Discard
- 2-card hand quota per character
- one combined 6-card visible hand
- unused cards retained
- same-character Redraw
- 3 shared Card Plays per turn
- rare explicit Heavy cards may consume 2 Plays
- one free adjacent Formation Adjustment per turn
- Sync as a separate advanced cooperation resource

## Draw decision

Selected:
per_character_quota.

Rejected as primary:
shared 24-card fair pool.

The shared pool generated more unique hands, but required extensive hidden deck searching/skipping and still produced character-absence events. The selected model has explicit ownership and deterministic refill semantics.

## Action economy decision

Selected:
3 Card Plays.

Rejected:
shared 4 AP as baseline.

The AP test did not suffer unused-resource fragmentation, so that is not a reason for rejection. Its observed costs were different:
- much higher filler-play rate
- much higher 2-cost retention
- lower full-three-character participation
- an AP cost curve required across the full card pool

3 Card Plays keeps the basic decision about card choice rather than resource arithmetic. Sync remains the higher-order team resource.

## Formation decision

Selected:
one free adjacent adjustment per turn.

Rejected:
- free arbitrary slot-to-slot swap
- one full Card Play per ordinary formation adjustment

Free arbitrary movement resolved virtually every position problem and weakened position pressure.

Charging one Card Play suppressed movement and produced threshold-sensitive behavior.

Free adjacent movement kept normal card throughput while resolving roughly two-thirds of simulated position needs, leaving meaningful multi-turn position pressure.

Emergency stronger/repeated movement may later consume Sync.

## Sync

Initial generation sources:
- Mark applied by one character and consumed by another
- Intercept protecting a teammate
- Link established by Loom and realized by another character

Autosim indicates natural generation is bounded and explicit Sync-farming is rarely attractive.

Do not turn Sync into a universal card cost or duplicate AP/energy.

## Architecture

BattleState is pure serializable state.

BattleCommand examples:
- PlayCard
- Redraw
- AdjustFormation
- UseCommandSkill
- Retreat
- EndTurn

BattleResolver owns:
- validation
- action ordering
- target resolution
- Counter/Intercept/Link timing
- EffectRuntime calls
- Intent resolution
- Sync generation
- retreat sequencing

Presentation must not mutate BattleState directly.

## Pending experiential validation

This file is not a declaration that combat is already fun.

Before final P0-3 closure:
- human playtest
- keyboard/controller/mouse smoke
- Card Framework presentation adapter smoke
- readability/targeting/formation UX smoke

If those reveal a serious problem, this technical baseline may still be revised before formal production.
