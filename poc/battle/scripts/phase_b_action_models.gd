extends SceneTree

const CHARACTERS := [&"char_bastion", &"char_falcon", &"char_loom"]
const CARDS_PER_CHARACTER := 8
const QUOTA := 2
const TURNS_PER_RUN := 12
const RUNS := 1000
const BASE_SEED := 880311
const AP_COSTS := [1, 1, 1, 2, 1, 2, 1, 2]
const UTILITIES := [3, 4, 5, 7, 4, 8, 5, 9]

class DeckState:
    var draw: Array = []
    var discard: Array = []

class Result:
    var turns := 0
    var cards_played := 0
    var budget_spent := 0
    var budget_total := 0
    var fragment_turns := 0
    var high_cost_retained_turns := 0
    var filler_turns := 0
    var all_three_roles_turns := 0
    var one_role_only_turns := 0
    var role_absence_events := 0
    var trace: Array = []

    func to_dict() -> Dictionary:
        return {
            "turns": turns,
            "avg_cards_played": float(cards_played) / maxf(1.0, float(turns)),
            "avg_budget_spent": float(budget_spent) / maxf(1.0, float(turns)),
            "avg_budget_unused": float(budget_total - budget_spent) / maxf(1.0, float(turns)),
            "budget_utilization": float(budget_spent) / maxf(1.0, float(budget_total)),
            "fragment_turn_rate": float(fragment_turns) / maxf(1.0, float(turns)),
            "high_cost_retained_rate": float(high_cost_retained_turns) / maxf(1.0, float(turns)),
            "filler_turn_rate": float(filler_turns) / maxf(1.0, float(turns)),
            "all_three_roles_participation_rate": float(all_three_roles_turns) / maxf(1.0, float(turns)),
            "one_role_only_rate": float(one_role_only_turns) / maxf(1.0, float(turns)),
            "role_absence_events": role_absence_events,
        }

func _init() -> void:
    var plays := _simulate("card_plays")
    var ap := _simulate("shared_ap")

    var replay_plays_a := _simulate("card_plays", 424242, 1)
    var replay_plays_b := _simulate("card_plays", 424242, 1)
    if JSON.stringify(replay_plays_a.trace) != JSON.stringify(replay_plays_b.trace):
        push_error("Card Plays deterministic replay failed")
        quit(2)
        return

    var replay_ap_a := _simulate("shared_ap", 424242, 1)
    var replay_ap_b := _simulate("shared_ap", 424242, 1)
    if JSON.stringify(replay_ap_a.trace) != JSON.stringify(replay_ap_b.trace):
        push_error("Shared AP deterministic replay failed")
        quit(3)
        return

    var summary := {
        "fixture": {
            "draw_model": "per_character_quota",
            "characters": CHARACTERS.map(func(v): return String(v)),
            "cards_per_character": CARDS_PER_CHARACTER,
            "quota": QUOTA,
            "turns_per_run": TURNS_PER_RUN,
            "runs": RUNS,
        },
        "card_plays": plays.to_dict(),
        "shared_ap": ap.to_dict(),
        "design_surface": {
            "card_plays_budget": 3,
            "card_plays_non_default_heavy_cards": 3,
            "shared_ap_budget": 4,
            "shared_ap_cards_requiring_cost_assignment": 24,
            "shared_ap_two_cost_cards": 9,
        },
        "deterministic_replay": {
            "card_plays": true,
            "shared_ap": true,
        },
    }

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://result/runtime"))
    var f := FileAccess.open("res://result/runtime/phase_b_summary.json", FileAccess.WRITE)
    if f == null:
        push_error("Could not create Phase B summary")
        quit(4)
        return
    f.store_string(JSON.stringify(summary, "  "))
    f.close()

    print("[P0-3:B] CARD_PLAYS | " + JSON.stringify(plays.to_dict()))
    print("[P0-3:B] SHARED_AP | " + JSON.stringify(ap.to_dict()))
    print("[P0-3:B] DETERMINISM PASS")
    print("[P0-3:B] PASS")
    quit(0)

func _make_card(character: StringName, index: int) -> Dictionary:
    return {
        "id": "%s_card_%02d" % [String(character), index],
        "character": character,
        "utility": UTILITIES[index],
        "plays_cost": 2 if index == 7 else 1,
        "ap_cost": AP_COSTS[index],
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

func _cost(card: Dictionary, model: String) -> int:
    return int(card["plays_cost"] if model == "card_plays" else card["ap_cost"])

func _budget(model: String) -> int:
    return 3 if model == "card_plays" else 4

func _select_best(hand: Array, model: String) -> Dictionary:
    var budget := _budget(model)
    var best_mask := 0
    var best_value := -1
    var best_count := -1
    var best_cost := -1

    for mask in range(1 << hand.size()):
        var total_cost := 0
        var total_value := 0
        var count := 0
        for i in range(hand.size()):
            if (mask & (1 << i)) == 0:
                continue
            var card: Dictionary = hand[i]
            total_cost += _cost(card, model)
            total_value += int(card["utility"])
            count += 1
        if total_cost > budget:
            continue

        var better := false
        if total_value > best_value:
            better = true
        elif total_value == best_value and count > best_count:
            better = true
        elif total_value == best_value and count == best_count and total_cost > best_cost:
            better = true
        if better:
            best_mask = mask
            best_value = total_value
            best_count = count
            best_cost = total_cost

    var selected: Array = []
    var unselected: Array = []
    for i in range(hand.size()):
        if (best_mask & (1 << i)) != 0:
            selected.append(hand[i])
        else:
            unselected.append(hand[i])

    return {"selected":selected,"unselected":unselected,"spent":best_cost,"value":best_value}

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

        for turn_index in range(TURNS_PER_RUN):
            for c in CHARACTERS:
                var role_hand: Array = hands[c]
                while role_hand.size() < QUOTA:
                    var card = _draw(decks[c], rng)
                    if card == null:
                        break
                    role_hand.append(card)

            var hand := _combined(hands)
            var selection := _select_best(hand, model)
            var selected: Array = selection["selected"]
            var unselected: Array = selection["unselected"]
            var spent := int(selection["spent"])
            var budget := _budget(model)
            var leftover := budget - spent

            result.turns += 1
            result.cards_played += selected.size()
            result.budget_spent += spent
            result.budget_total += budget

            var participation := {}
            for c in CHARACTERS:
                participation[c] = 0
            for raw in selected:
                var card: Dictionary = raw
                participation[card["character"]] = int(participation[card["character"]]) + 1

            var active_roles := 0
            for c in CHARACTERS:
                if int(participation[c]) > 0:
                    active_roles += 1
                else:
                    result.role_absence_events += 1
            if active_roles == 3:
                result.all_three_roles_turns += 1
            if active_roles == 1:
                result.one_role_only_turns += 1

            if leftover > 0:
                var any_fits := false
                for raw in unselected:
                    if _cost(raw, model) <= leftover:
                        any_fits = true
                        break
                if not any_fits:
                    result.fragment_turns += 1

            var retained_high_cost := false
            for raw in unselected:
                if _cost(raw, model) >= 2:
                    retained_high_cost = true
                    break
            if retained_high_cost:
                result.high_cost_retained_turns += 1

            var filler := false
            var max_unselected_utility := -1
            for raw in unselected:
                max_unselected_utility = maxi(max_unselected_utility, int((raw as Dictionary)["utility"]))
            for raw in selected:
                var card: Dictionary = raw
                if int(card["utility"]) <= 4 and max_unselected_utility >= 7:
                    filler = true
                    break
            if filler:
                result.filler_turns += 1

            if run_index == 0:
                result.trace.append({
                    "turn":turn_index,
                    "spent":spent,
                    "budget":budget,
                    "selected":selected.map(func(v): return String((v as Dictionary)["id"])),
                    "remaining":unselected.map(func(v): return String((v as Dictionary)["id"])),
                })

            for raw in selected:
                var card: Dictionary = raw
                var c: StringName = card["character"]
                hands[c].erase(card)
                decks[c].discard.append(card)

    return result
