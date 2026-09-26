extends SceneTree

const CHARACTERS := [&"char_bastion", &"char_falcon", &"char_loom"]
const CARDS_PER_CHARACTER := 8
const HAND_SIZE := 6
const QUOTA := 2
const PLAYS_PER_TURN := 3
const REDRAWS_PER_TURN := 2
const TURNS_PER_RUN := 12
const RUNS := 1000
const BASE_SEED := 730241

class DeckState:
    var draw: Array = []
    var discard: Array = []

class ModelResult:
    var turns: int = 0
    var exact_222: int = 0
    var character_absence: int = 0
    var concentration_3plus: int = 0
    var imbalance_sum: int = 0
    var guarantee_searches: int = 0
    var guarantee_cards_skipped: int = 0
    var redraw_searches: int = 0
    var redraw_cards_skipped: int = 0
    var unique_hand_signatures: Dictionary = {}
    var trace: Array = []

    func to_dict() -> Dictionary:
        return {
            "turns": turns,
            "exact_2_2_2_rate": float(exact_222) / maxf(1.0, float(turns)),
            "character_absence_events": character_absence,
            "character_absence_event_rate_per_turn": float(character_absence) / maxf(1.0, float(turns)),
            "concentration_3plus_turns": concentration_3plus,
            "concentration_3plus_rate": float(concentration_3plus) / maxf(1.0, float(turns)),
            "avg_role_count_imbalance": float(imbalance_sum) / maxf(1.0, float(turns)),
            "guarantee_searches": guarantee_searches,
            "guarantee_cards_skipped": guarantee_cards_skipped,
            "redraw_searches": redraw_searches,
            "redraw_cards_skipped": redraw_cards_skipped,
            "unique_hand_signatures": unique_hand_signatures.size(),
        }

func _init() -> void:
    var a1 := _simulate_per_character()
    var a2 := _simulate_shared_fair()

    var replay_a1 := _simulate_per_character(424242, 1)
    var replay_a1_b := _simulate_per_character(424242, 1)
    if JSON.stringify(replay_a1.trace) != JSON.stringify(replay_a1_b.trace):
        push_error("Per-character quota deterministic replay failed")
        quit(2)
        return

    var replay_a2 := _simulate_shared_fair(424242, 1)
    var replay_a2_b := _simulate_shared_fair(424242, 1)
    if JSON.stringify(replay_a2.trace) != JSON.stringify(replay_a2_b.trace):
        push_error("Shared fair pool deterministic replay failed")
        quit(3)
        return

    var summary := {
        "fixture": {
            "characters": CHARACTERS.map(func(v): return String(v)),
            "cards_per_character": CARDS_PER_CHARACTER,
            "hand_size": HAND_SIZE,
            "plays_per_turn": PLAYS_PER_TURN,
            "redraws_per_turn": REDRAWS_PER_TURN,
            "turns_per_run": TURNS_PER_RUN,
            "runs": RUNS,
        },
        "per_character_quota": a1.to_dict(),
        "shared_fair_pool": a2.to_dict(),
        "deterministic_replay": {
            "per_character_quota": true,
            "shared_fair_pool": true,
        },
        "phase_a_observation": {
            "shared_fair_pool_absence_is_candidate_result": true,
            "winner_for_phase_b": "per_character_quota",
        },
    }

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://result/runtime"))
    var f := FileAccess.open("res://result/runtime/phase_a_summary.json", FileAccess.WRITE)
    if f == null:
        push_error("Could not create Phase A summary")
        quit(4)
        return
    f.store_string(JSON.stringify(summary, "  "))
    f.close()

    print("[P0-3:A] PER_CHARACTER | " + JSON.stringify(a1.to_dict()))
    print("[P0-3:A] SHARED_FAIR | " + JSON.stringify(a2.to_dict()))
    print("[P0-3:A] DETERMINISM PASS")

    if a1.character_absence != 0:
        push_error("Per-character quota produced character absence")
        quit(5)
        return
    if a1.exact_222 != a1.turns:
        push_error("Per-character quota violated 2/2/2 invariant")
        quit(6)
        return
    if a2.character_absence != 0:
        print("[P0-3:A] OBSERVATION | shared fair pool still produced character absence after redraw/search")
    if a2.guarantee_searches <= 0 or a2.redraw_searches <= 0:
        push_error("Shared fair pool did not exercise its fairness-search rules")
        quit(7)
        return

    print("[P0-3:A] WINNER_FOR_PHASE_B | per_character_quota")
    print("[P0-3:A] PASS")
    quit(0)

func _make_card(character: StringName, index: int) -> Dictionary:
    return {
        "id": "%s_card_%02d" % [String(character), index],
        "character": character,
    }

func _new_character_decks(rng: RandomNumberGenerator) -> Dictionary:
    var decks := {}
    for c in CHARACTERS:
        var state := DeckState.new()
        for i in range(CARDS_PER_CHARACTER):
            state.draw.append(_make_card(c, i))
        _shuffle(state.draw, rng)
        decks[c] = state
    return decks

func _new_shared_deck(rng: RandomNumberGenerator) -> DeckState:
    var state := DeckState.new()
    for c in CHARACTERS:
        for i in range(CARDS_PER_CHARACTER):
            state.draw.append(_make_card(c, i))
    _shuffle(state.draw, rng)
    return state

func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
    for i in range(items.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var tmp = items[i]
        items[i] = items[j]
        items[j] = tmp

func _draw_from_character(state: DeckState, rng: RandomNumberGenerator):
    if state.draw.is_empty():
        state.draw = state.discard
        state.discard = []
        _shuffle(state.draw, rng)
    if state.draw.is_empty():
        return null
    return state.draw.pop_back()

func _draw_shared_top(state: DeckState, rng: RandomNumberGenerator):
    if state.draw.is_empty():
        state.draw = state.discard
        state.discard = []
        _shuffle(state.draw, rng)
    if state.draw.is_empty():
        return null
    return state.draw.pop_back()

func _search_shared_character(state: DeckState, character: StringName, rng: RandomNumberGenerator) -> Dictionary:
    if state.draw.is_empty():
        state.draw = state.discard
        state.discard = []
        _shuffle(state.draw, rng)

    for offset in range(state.draw.size()):
        var idx := state.draw.size() - 1 - offset
        var card: Dictionary = state.draw[idx]
        if card["character"] == character:
            state.draw.remove_at(idx)
            return {"card": card, "skipped": offset}

    return {"card": null, "skipped": state.draw.size()}

func _counts(hand: Array) -> Dictionary:
    var counts := {}
    for c in CHARACTERS:
        counts[c] = 0
    for raw in hand:
        var card: Dictionary = raw
        counts[card["character"]] = int(counts[card["character"]]) + 1
    return counts

func _record_hand(result: ModelResult, hand: Array, run_index: int, turn_index: int) -> void:
    result.turns += 1
    var counts := _counts(hand)
    var values: Array[int] = []
    var exact := true
    var has_three := false

    for c in CHARACTERS:
        var n := int(counts[c])
        values.append(n)
        if n == 0:
            result.character_absence += 1
        if n != 2:
            exact = false
        if n >= 3:
            has_three = true

    if exact:
        result.exact_222 += 1
    if has_three:
        result.concentration_3plus += 1

    values.sort()
    result.imbalance_sum += values[-1] - values[0]

    var ids: Array[String] = []
    for raw in hand:
        ids.append(String((raw as Dictionary)["id"]))
    ids.sort()
    result.unique_hand_signatures["|".join(ids)] = true

    if run_index == 0:
        result.trace.append({
            "turn": turn_index,
            "counts": {
                "bastion": counts[&"char_bastion"],
                "falcon": counts[&"char_falcon"],
                "loom": counts[&"char_loom"],
            },
            "cards": ids,
        })

func _random_hand_index(hand: Array, rng: RandomNumberGenerator) -> int:
    return rng.randi_range(0, hand.size() - 1)

func _play_random_cards(hand: Array, rng: RandomNumberGenerator, on_discard: Callable) -> void:
    var plays := mini(PLAYS_PER_TURN, hand.size())
    for _i in range(plays):
        var idx := _random_hand_index(hand, rng)
        var card = hand[idx]
        hand.remove_at(idx)
        on_discard.call(card)

func _simulate_per_character(seed_override: int = -1, runs_override: int = -1) -> ModelResult:
    var result := ModelResult.new()
    var total_runs := RUNS if runs_override < 0 else runs_override

    for run_index in range(total_runs):
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_override if seed_override >= 0 else BASE_SEED + run_index
        var decks := _new_character_decks(rng)
        var hands := {}
        for c in CHARACTERS:
            hands[c] = []

        for turn_index in range(TURNS_PER_RUN):
            for c in CHARACTERS:
                var hand: Array = hands[c]
                while hand.size() < QUOTA:
                    var card = _draw_from_character(decks[c], rng)
                    if card == null:
                        break
                    hand.append(card)

            var combined: Array = []
            for c in CHARACTERS:
                combined.append_array(hands[c])

            for _redraw in range(REDRAWS_PER_TURN):
                var idx := _random_hand_index(combined, rng)
                var old: Dictionary = combined[idx]
                var c: StringName = old["character"]
                hands[c].erase(old)
                decks[c].discard.append(old)
                var replacement = _draw_from_character(decks[c], rng)
                if replacement != null:
                    hands[c].append(replacement)
                combined = []
                for each in CHARACTERS:
                    combined.append_array(hands[each])

            _record_hand(result, combined, run_index, turn_index)

            _play_random_cards(combined, rng, func(card):
                var c: StringName = card["character"]
                hands[c].erase(card)
                decks[c].discard.append(card)
            )

    return result

func _simulate_shared_fair(seed_override: int = -1, runs_override: int = -1) -> ModelResult:
    var result := ModelResult.new()
    var total_runs := RUNS if runs_override < 0 else runs_override

    for run_index in range(total_runs):
        var rng := RandomNumberGenerator.new()
        rng.seed = seed_override if seed_override >= 0 else BASE_SEED + run_index
        var deck := _new_shared_deck(rng)
        var hand: Array = []

        for turn_index in range(TURNS_PER_RUN):
            var counts := _counts(hand)
            for c in CHARACTERS:
                if int(counts[c]) == 0 and hand.size() < HAND_SIZE:
                    var found := _search_shared_character(deck, c, rng)
                    result.guarantee_searches += 1
                    result.guarantee_cards_skipped += int(found["skipped"])
                    if found["card"] != null:
                        hand.append(found["card"])

            while hand.size() < HAND_SIZE:
                var card = _draw_shared_top(deck, rng)
                if card == null:
                    break
                hand.append(card)

            for _redraw in range(REDRAWS_PER_TURN):
                var idx := _random_hand_index(hand, rng)
                var old: Dictionary = hand[idx]
                var c: StringName = old["character"]
                deck.discard.append(old)
                hand.remove_at(idx)
                var found := _search_shared_character(deck, c, rng)
                result.redraw_searches += 1
                result.redraw_cards_skipped += int(found["skipped"])
                if found["card"] != null:
                    hand.append(found["card"])

            _record_hand(result, hand, run_index, turn_index)

            _play_random_cards(hand, rng, func(card):
                deck.discard.append(card)
            )

    return result