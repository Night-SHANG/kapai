extends SceneTree

const CHARACTERS := [&"char_bastion", &"char_falcon", &"char_loom"]
const PREFERRED_POSITION := {
    &"char_bastion": 0,
    &"char_loom": 1,
    &"char_falcon": 2,
}
const CARDS_PER_CHARACTER := 8
const QUOTA := 2
const TURNS_PER_RUN := 12
const RUNS := 1000
const BASE_SEED := 991337
const HAZARD_PENALTY := 6
const POSITION_BONUS := 2

class DeckState:
    var draw: Array = []
    var discard: Array = []

class Result:
    var turns := 0
    var formation_need_turns := 0
    var formation_adjustments := 0
    var formation_action_cost_total := 0
    var cards_played := 0
    var natural_sync := 0
    var sync_turns := 0
    var farm_opportunity_turns := 0
    var farm_extra_sync := 0
    var farm_utility_sacrifice := 0
    var trace: Array = []

    func to_dict() -> Dictionary:
        return {
            "turns": turns,
            "formation_need_turns": formation_need_turns,
            "formation_adjustments": formation_adjustments,
            "formation_response_rate": float(formation_adjustments) / maxf(1.0, float(formation_need_turns)),
            "formation_action_cost_total": formation_action_cost_total,
            "avg_cards_played": float(cards_played) / maxf(1.0, float(turns)),
            "natural_sync_total": natural_sync,
            "sync_per_3_turns": 3.0 * float(natural_sync) / maxf(1.0, float(turns)),
            "sync_turn_rate": float(sync_turns) / maxf(1.0, float(turns)),
            "farm_opportunity_rate": float(farm_opportunity_turns) / maxf(1.0, float(turns)),
            "farm_extra_sync_total": farm_extra_sync,
            "avg_utility_sacrifice_per_extra_sync": float(farm_utility_sacrifice) / maxf(1.0, float(farm_extra_sync)),
        }

func _init() -> void:
    var free := _simulate("free_adjustment")
    var paid := _simulate("cost_one_play")

    var replay_free_a := _simulate("free_adjustment", 424242, 1)
    var replay_free_b := _simulate("free_adjustment", 424242, 1)
    if JSON.stringify(replay_free_a.trace) != JSON.stringify(replay_free_b.trace):
        push_error("Free formation deterministic replay failed")
        quit(2)
        return

    var replay_paid_a := _simulate("cost_one_play", 424242, 1)
    var replay_paid_b := _simulate("cost_one_play", 424242, 1)
    if JSON.stringify(replay_paid_a.trace) != JSON.stringify(replay_paid_b.trace):
        push_error("Paid formation deterministic replay failed")
        quit(3)
        return

    var summary := {
        "fixture": {
            "draw_model": "per_character_quota",
            "action_model": "3_card_plays",
            "characters": CHARACTERS.map(func(v): return String(v)),
            "turns_per_run": TURNS_PER_RUN,
            "runs": RUNS,
            "hazard_penalty": HAZARD_PENALTY,
            "preferred_position_bonus": POSITION_BONUS,
            "sync_triggers": ["mark_consume", "intercept", "link"],
        },
        "free_adjustment": free.to_dict(),
        "cost_one_play": paid.to_dict(),
        "deterministic_replay": {
            "free_adjustment": true,
            "cost_one_play": true,
        },
    }

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://result/runtime"))
    var f := FileAccess.open("res://result/runtime/phase_c_summary.json", FileAccess.WRITE)
    if f == null:
        push_error("Could not create Phase C summary")
        quit(4)
        return
    f.store_string(JSON.stringify(summary, "  "))
    f.close()

    print("[P0-3:C] FREE | " + JSON.stringify(free.to_dict()))
    print("[P0-3:C] PAID | " + JSON.stringify(paid.to_dict()))
    print("[P0-3:C] DETERMINISM PASS")
    print("[P0-3:C] PASS")
    quit(0)

func _make_card(character: StringName, index: int) -> Dictionary:
    var kind := "normal"
    if character == &"char_bastion" and index == 0:
        kind = "intercept"
    elif character == &"char_bastion" and index == 1:
        kind = "mark_consumer"
    elif character == &"char_falcon" and index == 0:
        kind = "mark"
    elif character == &"char_loom" and index == 0:
        kind = "link"
    elif character == &"char_loom" and index == 1:
        kind = "mark_consumer"

    var base_utilities := [6, 6, 5, 7, 4, 8, 5, 9]
    return {
        "id": "%s_card_%02d" % [String(character), index],
        "character": character,
        "kind": kind,
        "utility": base_utilities[index],
    }

func _new_decks(rng: RandomNumberGenerator) -> Dictionary:
    var decks := {}
    for c in CHARACTERS:
        var state := DeckState.new()
        for i in range(CARDS_PER_CHARACTER):
            state.draw.append(_make_card(c, i))
        _shuffle(state.draw, rng)
        decks[c] = state
    return decks

func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
    for i in range(items.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = items[i]
        items[i] = items[j]
        items[j] = tmp

func _draw(state: DeckState, rng: RandomNumberGenerator):
    if state.draw.is_empty():
        state.draw = state.discard
        state.discard = []
        _shuffle(state.draw, rng)
    if state.draw.is_empty():
        return null
    return state.draw.pop_back()

func _combined(hands: Dictionary) -> Array:
    var out: Array = []
    for c in CHARACTERS:
        out.append_array(hands[c])
    return out

func _position_of(formation: Array, character: StringName) -> int:
    return formation.find(character)

func _card_utility(card: Dictionary, formation: Array) -> int:
    var value := int(card["utility"])
    var character: StringName = card["character"]
    if _position_of(formation, character) == int(PREFERRED_POSITION[character]):
        value += POSITION_BONUS
    return value

func _sync_from_subset(selected: Array, enemy_target: StringName) -> int:
    var has_mark := false
    var has_consumer := false
    var has_intercept := false
    var has_link := false
    var has_non_loom := false

    for raw in selected:
        var card: Dictionary = raw
        match String(card["kind"]):
            "mark":
                has_mark = true
            "mark_consumer":
                has_consumer = true
            "intercept":
                has_intercept = true
            "link":
                has_link = true
        if card["character"] != &"char_loom":
            has_non_loom = true

    var sync := 0
    if has_mark and has_consumer:
        sync += 1
    if has_intercept and enemy_target != &"char_bastion":
        sync += 1
    if has_link and has_non_loom:
        sync += 1
    return sync

func _best_subset(hand: Array, budget: int, formation: Array, enemy_target: StringName, prioritize_sync: bool) -> Dictionary:
    var best_mask := 0
    var best_utility := -999999
    var best_sync := -1
    var best_count := -1

    for mask in range(1 << hand.size()):
        var count := 0
        var utility := 0
        var selected: Array = []

        for i in range(hand.size()):
            if (mask & (1 << i)) == 0:
                continue
            count += 1
            if count > budget:
                break
            var card: Dictionary = hand[i]
            selected.append(card)
            utility += _card_utility(card, formation)

        if count > budget:
            continue

        var sync := _sync_from_subset(selected, enemy_target)
        var better := false
        if prioritize_sync:
            if sync > best_sync:
                better = true
            elif sync == best_sync and utility > best_utility:
                better = true
            elif sync == best_sync and utility == best_utility and count > best_count:
                better = true
        else:
            if utility > best_utility:
                better = true
            elif utility == best_utility and sync > best_sync:
                better = true
            elif utility == best_utility and sync == best_sync and count > best_count:
                better = true

        if better:
            best_mask = mask
            best_utility = utility
            best_sync = sync
            best_count = count

    var selected: Array = []
    for i in range(hand.size()):
        if (best_mask & (1 << i)) != 0:
            selected.append(hand[i])

    return {
        "selected": selected,
        "utility": best_utility,
        "sync": best_sync,
    }

func _swapped(formation: Array, character: StringName, desired_pos: int) -> Array:
    var out := formation.duplicate()
    var current := out.find(character)
    if current == -1 or current == desired_pos:
        return out
    var other = out[desired_pos]
    out[desired_pos] = character
    out[current] = other
    return out

func _simulate(model: String, seed_override: int = -1, runs_override: int = -1) -> Result:
    var result := Result.new()
    var total_runs := RUNS if runs_override < 0 else runs_override

    for run_index in range(total_runs):
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_override if seed_override >= 0 else BASE_SEED + run_index
        var decks := _new_decks(rng)
        var hands := {}
        for c in CHARACTERS:
            hands[c] = []

        var formation: Array = [&"char_bastion", &"char_loom", &"char_falcon"]

        for turn_index in range(TURNS_PER_RUN):
            for c in CHARACTERS:
                var role_hand: Array = hands[c]
                while role_hand.size() < QUOTA:
                    var card = _draw(decks[c], rng)
                    if card == null:
                        break
                    role_hand.append(card)

            var hand := _combined(hands)
            var enemy_target: StringName = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]

            var has_formation_need := rng.randf() < 0.55
            var need_character: StringName = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]
            var desired_pos := rng.randi_range(0, 2)
            var mismatch := has_formation_need and _position_of(formation, need_character) != desired_pos

            var action_budget := 3
            var chosen_formation := formation
            var adjusted := false

            if mismatch:
                result.formation_need_turns += 1
                var stay := _best_subset(hand, 3, formation, enemy_target, false)
                var moved_formation := _swapped(formation, need_character, desired_pos)
                var move_budget := 3 if model == "free_adjustment" else 2
                var moved := _best_subset(hand, move_budget, moved_formation, enemy_target, false)

                var stay_score := int(stay["utility"]) - HAZARD_PENALTY
                var move_score := int(moved["utility"])

                if move_score > stay_score:
                    adjusted = true
                    chosen_formation = moved_formation
                    action_budget = move_budget
                    result.formation_adjustments += 1
                    if model == "cost_one_play":
                        result.formation_action_cost_total += 1

            formation = chosen_formation

            var natural := _best_subset(hand, action_budget, formation, enemy_target, false)
            var sync_first := _best_subset(hand, action_budget, formation, enemy_target, true)
            var selected: Array = natural["selected"]

            result.turns += 1
            result.cards_played += selected.size()
            var natural_sync := int(natural["sync"])
            result.natural_sync += natural_sync
            if natural_sync > 0:
                result.sync_turns += 1

            var max_sync := int(sync_first["sync"])
            if max_sync > natural_sync:
                result.farm_opportunity_turns += 1
                var extra := max_sync - natural_sync
                result.farm_extra_sync += extra
                result.farm_utility_sacrifice += maxi(0, int(natural["utility"]) - int(sync_first["utility"]))

            if run_index == 0:
                result.trace.append({
                    "turn": turn_index,
                    "model": model,
                    "formation": formation.map(func(v): return String(v)),
                    "formation_need": mismatch,
                    "adjusted": adjusted,
                    "budget": action_budget,
                    "enemy_target": String(enemy_target),
                    "selected": selected.map(func(v): return String((v as Dictionary)["id"])),
                    "sync": natural_sync,
                    "farm_sync": max_sync,
                    "natural_utility": natural["utility"],
                    "farm_utility": sync_first["utility"],
                })

            for raw in selected:
                var card: Dictionary = raw
                var c: StringName = card["character"]
                hands[c].erase(card)
                decks[c].discard.append(card)

    return result
