extends SceneTree

const CHARACTERS := [&"char_bastion", &"char_falcon", &"char_loom"]
const CARDS_PER_CHARACTER := 8
const QUOTA := 2
const TURN_COUNT := 12
const DRAW_SEED_OFFSET := 101
const AI_SEED_OFFSET := 907

func _init() -> void:
    var recorded := _record_run(24681357)
    if not bool(recorded.get("ok", false)):
        push_error("Phase D record run failed: %s" % recorded.get("error", "unknown"))
        quit(2)
        return

    var replay := _replay_run(24681357, recorded["commands"], recorded["hashes"])
    if not bool(replay.get("ok", false)):
        push_error("Phase D replay failed: %s" % replay.get("error", "unknown"))
        quit(3)
        return

    var state: Dictionary = recorded["state"]
    if int(state["turn"]) != TURN_COUNT + 1:
        push_error("Expected %d completed turns, got state turn %d" % [TURN_COUNT, state["turn"]])
        quit(4)
        return
    if int(state["sync_generated_total"]) <= 0:
        push_error("No cooperation Sync was generated during Phase D")
        quit(5)
        return
    if int(recorded["invariant_checks"]) < 40:
        push_error("Too few invariant checks: %s" % recorded["invariant_checks"])
        quit(6)
        return

    var isolation := _rng_isolation_probe(97531)
    if not bool(isolation["pass"]):
        push_error("RNG stream isolation failed: %s" % JSON.stringify(isolation))
        quit(7)
        return

    var summary := {
        "turns_completed": TURN_COUNT,
        "commands": (recorded["commands"] as Array).size(),
        "state_hashes_checked": (recorded["hashes"] as Array).size(),
        "invariant_checks": recorded["invariant_checks"],
        "sync_generated_total": state["sync_generated_total"],
        "sync_spent_total": state["sync_spent_total"],
        "final_sync": state["sync"],
        "final_formation": (state["formation"] as Array).map(func(v): return String(v)),
        "enemy_hp": state["enemy_hp"],
        "ally_hp": _ally_hp_snapshot(state),
        "final_intent": state["enemy_intent"],
        "draw_rng_state": (state["draw_rng"] as RandomNumberGenerator).state,
        "ai_rng_state": (state["ai_rng"] as RandomNumberGenerator).state,
        "rng_stream_isolation": isolation,
        "deterministic_replay": true,
        "final_rules": {
            "draw_model": "per_character_quota",
            "quota_per_character": QUOTA,
            "visible_hand_target": 6,
            "card_plays_per_turn": 3,
            "redraws_per_turn": 2,
            "formation": "one_free_adjacent_swap_per_turn",
            "extra_formation": "spend_1_sync",
            "sync_sources": ["mark_consumed_by_other_character", "intercept_for_ally", "link_with_other_character"],
            "intent": "visible_before_player_actions",
            "rng_streams": ["battle_draw", "enemy_ai"],
        },
    }

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://result/runtime"))
    var file := FileAccess.open("res://result/runtime/phase_d_summary.json", FileAccess.WRITE)
    if file == null:
        push_error("Could not write Phase D summary")
        quit(8)
        return
    file.store_string(JSON.stringify(summary, "  "))
    file.close()

    print("[P0-3:D] SUMMARY | " + JSON.stringify(summary))
    print("[P0-3:D] REPLAY PASS | commands=%d | hashes=%d" % [
        (recorded["commands"] as Array).size(),
        (recorded["hashes"] as Array).size(),
    ])
    print("[P0-3:D] PASS")
    quit(0)

func _new_state(seed: int) -> Dictionary:
    var draw_rng := RandomNumberGenerator.new()
    draw_rng.seed = seed + DRAW_SEED_OFFSET

    var ai_rng := RandomNumberGenerator.new()
    ai_rng.seed = seed + AI_SEED_OFFSET

    var draws := {}
    var discards := {}
    var hands := {}

    for character in CHARACTERS:
        var cards: Array = []
        for index in range(CARDS_PER_CHARACTER):
            cards.append(_make_card(character, index))
        _shuffle(cards, draw_rng)
        draws[character] = cards
        discards[character] = []
        hands[character] = []

    var state := {
        "turn": 1,
        "draw": draws,
        "discard": discards,
        "hands": hands,
        "formation": [&"char_bastion", &"char_loom", &"char_falcon"],
        "plays_remaining": 3,
        "redraws_remaining": 2,
        "formation_free_remaining": true,
        "sync": 0,
        "sync_generated_total": 0,
        "sync_spent_total": 0,
        "enemy_hp": 120,
        "enemy_mark_source": &"",
        "ally_hp": {
            &"char_bastion": 36,
            &"char_falcon": 28,
            &"char_loom": 30,
        },
        "enemy_intent": {},
        "draw_rng": draw_rng,
        "ai_rng": ai_rng,
    }

    _refill_hand(state)
    _roll_intent(state)
    return state

func _make_card(character: StringName, index: int) -> Dictionary:
    var kind := "attack"
    if character == &"char_bastion" and index == 0:
        kind = "intercept"
    elif character == &"char_falcon" and index == 0:
        kind = "mark"
    elif character == &"char_loom" and index == 0:
        kind = "link"

    return {
        "id": "%s_card_%02d" % [String(character), index],
        "character": character,
        "index": index,
        "kind": kind,
        "damage": 2 + (index % 4),
        "play_cost": 2 if index == 7 else 1,
    }

func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
    for i in range(items.size() - 1, 0, -1):
        var j := rng.randi_range(0, i)
        var temp = items[i]
        items[i] = items[j]
        items[j] = temp

func _draw_one(state: Dictionary, character: StringName):
    var draw: Array = state["draw"][character]
    var discard: Array = state["discard"][character]
    var rng: RandomNumberGenerator = state["draw_rng"]

    if draw.is_empty():
        draw.append_array(discard)
        discard.clear()
        _shuffle(draw, rng)

    if draw.is_empty():
        return null
    return draw.pop_back()

func _refill_hand(state: Dictionary) -> void:
    for character in CHARACTERS:
        var hand: Array = state["hands"][character]
        while hand.size() < QUOTA:
            var card = _draw_one(state, character)
            if card == null:
                break
            hand.append(card)

func _roll_intent(state: Dictionary) -> void:
    var rng: RandomNumberGenerator = state["ai_rng"]
    var kind_roll := rng.randi_range(0, 2)
    var target: StringName = CHARACTERS[rng.randi_range(0, CHARACTERS.size() - 1)]

    match kind_roll:
        0:
            state["enemy_intent"] = {
                "id": "intent_attack_light",
                "type": "attack",
                "target": target,
                "damage": 3,
            }
        1:
            state["enemy_intent"] = {
                "id": "intent_attack_heavy",
                "type": "attack",
                "target": target,
                "damage": 5,
            }
        _:
            state["enemy_intent"] = {
                "id": "intent_disrupt",
                "type": "formation_interference",
                "target": target,
                "damage": 1,
            }

func _find_card(state: Dictionary, card_id: String) -> Dictionary:
    for character in CHARACTERS:
        for raw in state["hands"][character]:
            var card: Dictionary = raw
            if String(card["id"]) == card_id:
                return card
    return {}

func _remove_card_from_hand(state: Dictionary, card: Dictionary) -> void:
    var character: StringName = card["character"]
    var hand: Array = state["hands"][character]
    hand.erase(card)

func _discard_card(state: Dictionary, card: Dictionary) -> void:
    var character: StringName = card["character"]
    (state["discard"][character] as Array).append(card)

func _apply_command(state: Dictionary, command: Dictionary) -> Dictionary:
    var result := {"ok": false, "error": ""}

    match String(command["type"]):
        "redraw":
            if int(state["redraws_remaining"]) <= 0:
                result["error"] = "No redraws remaining"
                return result

            var card := _find_card(state, String(command["card_id"]))
            if card.is_empty():
                result["error"] = "Redraw card not in hand: %s" % command["card_id"]
                return result

            var ai_before := (state["ai_rng"] as RandomNumberGenerator).state
            var character: StringName = card["character"]
            _remove_card_from_hand(state, card)
            _discard_card(state, card)
            var replacement = _draw_one(state, character)
            if replacement != null:
                (state["hands"][character] as Array).append(replacement)
            state["redraws_remaining"] = int(state["redraws_remaining"]) - 1

            if (state["ai_rng"] as RandomNumberGenerator).state != ai_before:
                result["error"] = "Redraw mutated enemy_ai RNG stream"
                return result

        "swap_adjacent":
            var left := int(command["left_index"])
            if left < 0 or left > 1:
                result["error"] = "Invalid adjacent swap index"
                return result

            var use_sync := bool(command.get("use_sync", false))
            if use_sync:
                if bool(state["formation_free_remaining"]):
                    result["error"] = "Cannot spend Sync while free formation is still available"
                    return result
                if int(state["sync"]) <= 0:
                    result["error"] = "No Sync for extra formation"
                    return result
                state["sync"] = int(state["sync"]) - 1
                state["sync_spent_total"] = int(state["sync_spent_total"]) + 1
            else:
                if not bool(state["formation_free_remaining"]):
                    result["error"] = "Free formation already used"
                    return result
                state["formation_free_remaining"] = false

            var formation: Array = state["formation"]
            var temp = formation[left]
            formation[left] = formation[left + 1]
            formation[left + 1] = temp

        "play_card":
            var card := _find_card(state, String(command["card_id"]))
            if card.is_empty():
                result["error"] = "Play card not in hand: %s" % command["card_id"]
                return result

            var cost := int(card["play_cost"])
            if int(state["plays_remaining"]) < cost:
                result["error"] = "Not enough Card Plays for %s" % command["card_id"]
                return result

            state["plays_remaining"] = int(state["plays_remaining"]) - cost
            _resolve_card(state, card)
            _remove_card_from_hand(state, card)
            _discard_card(state, card)

        "end_turn":
            _resolve_enemy_intent(state)
            state["enemy_mark_source"] = &""
            state["turn"] = int(state["turn"]) + 1
            state["plays_remaining"] = 3
            state["redraws_remaining"] = 2
            state["formation_free_remaining"] = true
            _refill_hand(state)
            _roll_intent(state)

        _:
            result["error"] = "Unknown command: %s" % command["type"]
            return result

    result["ok"] = true
    return result

func _resolve_card(state: Dictionary, card: Dictionary) -> void:
    var character: StringName = card["character"]
    var kind := String(card["kind"])

    match kind:
        "mark":
            state["enemy_mark_source"] = character
        "link":
            var mark_source: StringName = state["enemy_mark_source"]
            if mark_source != &"" and mark_source != character:
                state["enemy_mark_source"] = &""
                _gain_sync(state)
            else:
                state["enemy_hp"] = maxi(0, int(state["enemy_hp"]) - int(card["damage"]))
        "intercept":
            var target: StringName = state["enemy_intent"].get("target", &"")
            if target != &"" and target != character:
                _gain_sync(state)
            else:
                state["enemy_hp"] = maxi(0, int(state["enemy_hp"]) - int(card["damage"]))
        _:
            state["enemy_hp"] = maxi(0, int(state["enemy_hp"]) - int(card["damage"]))

func _gain_sync(state: Dictionary) -> void:
    state["sync"] = int(state["sync"]) + 1
    state["sync_generated_total"] = int(state["sync_generated_total"]) + 1

func _resolve_enemy_intent(state: Dictionary) -> void:
    var intent: Dictionary = state["enemy_intent"]
    var target: StringName = intent.get("target", &"")
    if target == &"":
        return
    var hp: Dictionary = state["ally_hp"]
    hp[target] = maxi(0, int(hp[target]) - int(intent.get("damage", 0)))

func _choose_play_card(state: Dictionary) -> Dictionary:
    var affordable: Array[Dictionary] = []
    for character in CHARACTERS:
        for raw in state["hands"][character]:
            var card: Dictionary = raw
            if int(card["play_cost"]) <= int(state["plays_remaining"]):
                affordable.append(card)

    if affordable.is_empty():
        return {}

    var mark_present := StringName(state["enemy_mark_source"]) != &""

    for card in affordable:
        if String(card["kind"]) == "link" and mark_present:
            return card

    for card in affordable:
        if String(card["kind"]) == "mark" and not mark_present:
            return card

    for card in affordable:
        if String(card["kind"]) == "intercept":
            var target: StringName = state["enemy_intent"].get("target", &"")
            if target != card["character"]:
                return card

    affordable.sort_custom(func(a: Dictionary, b: Dictionary):
        if int(a["damage"]) == int(b["damage"]):
            return String(a["id"]) < String(b["id"])
        return int(a["damage"]) > int(b["damage"])
    )
    return affordable[0]

func _execute_recorded(state: Dictionary, command: Dictionary, commands: Array, hashes: Array) -> Dictionary:
    var result := _apply_command(state, command)
    if not bool(result["ok"]):
        return result
    commands.append(command.duplicate(true))
    var invariant := _check_invariants(state)
    if not bool(invariant["ok"]):
        return invariant
    hashes.append(_state_hash(state))
    return {"ok": true}

func _record_run(seed: int) -> Dictionary:
    var state := _new_state(seed)
    var commands: Array = []
    var hashes: Array = []
    var invariant_checks := 0

    var initial := _check_invariants(state)
    if not bool(initial["ok"]):
        return initial
    invariant_checks += 1

    for turn_index in range(TURN_COUNT):
        if turn_index % 2 == 0:
            var falcon_hand: Array = state["hands"][&"char_falcon"]
            if not falcon_hand.is_empty():
                var redraw_cmd := {
                    "type": "redraw",
                    "card_id": String((falcon_hand[0] as Dictionary)["id"]),
                }
                var rr := _execute_recorded(state, redraw_cmd, commands, hashes)
                if not bool(rr["ok"]):
                    return rr
                invariant_checks += 1

        if turn_index % 2 == 1:
            var free_swap := {
                "type": "swap_adjacent",
                "left_index": turn_index % 2,
                "use_sync": false,
            }
            var fr := _execute_recorded(state, free_swap, commands, hashes)
            if not bool(fr["ok"]):
                return fr
            invariant_checks += 1

        while int(state["plays_remaining"]) > 0:
            var card := _choose_play_card(state)
            if card.is_empty():
                break
            var play_cmd := {
                "type": "play_card",
                "card_id": String(card["id"]),
            }
            var pr := _execute_recorded(state, play_cmd, commands, hashes)
            if not bool(pr["ok"]):
                return pr
            invariant_checks += 1

        if turn_index % 4 == 3 and not bool(state["formation_free_remaining"]) and int(state["sync"]) > 0:
            var extra_swap := {
                "type": "swap_adjacent",
                "left_index": 0,
                "use_sync": true,
            }
            var sr := _execute_recorded(state, extra_swap, commands, hashes)
            if not bool(sr["ok"]):
                return sr
            invariant_checks += 1

        var end_cmd := {"type": "end_turn"}
        var er := _execute_recorded(state, end_cmd, commands, hashes)
        if not bool(er["ok"]):
            return er
        invariant_checks += 1

    return {
        "ok": true,
        "state": state,
        "commands": commands,
        "hashes": hashes,
        "invariant_checks": invariant_checks,
    }

func _replay_run(seed: int, commands: Array, expected_hashes: Array) -> Dictionary:
    var state := _new_state(seed)
    if commands.size() != expected_hashes.size():
        return {"ok": false, "error": "Command/hash size mismatch"}

    for i in range(commands.size()):
        var result := _apply_command(state, commands[i])
        if not bool(result["ok"]):
            return {"ok": false, "error": "Replay command %d failed: %s" % [i, result["error"]]}
        var invariant := _check_invariants(state)
        if not bool(invariant["ok"]):
            return {"ok": false, "error": "Replay invariant %d failed: %s" % [i, invariant["error"]]}
        var actual := _state_hash(state)
        if actual != expected_hashes[i]:
            return {
                "ok": false,
                "error": "State mismatch at command %d\nEXPECTED=%s\nACTUAL=%s" % [i, expected_hashes[i], actual],
            }

    return {"ok": true, "state": state}

func _check_invariants(state: Dictionary) -> Dictionary:
    var formation: Array = state["formation"]
    if formation.size() != 3:
        return {"ok": false, "error": "Formation size != 3"}

    var unique := {}
    for character in formation:
        unique[character] = true
    if unique.size() != 3:
        return {"ok": false, "error": "Formation contains duplicate characters"}

    for character in CHARACTERS:
        if not unique.has(character):
            return {"ok": false, "error": "Formation missing %s" % character}
        if (state["hands"][character] as Array).size() > QUOTA:
            return {"ok": false, "error": "Hand quota exceeded for %s" % character}

    if int(state["plays_remaining"]) < 0 or int(state["plays_remaining"]) > 3:
        return {"ok": false, "error": "Invalid plays_remaining"}
    if int(state["redraws_remaining"]) < 0 or int(state["redraws_remaining"]) > 2:
        return {"ok": false, "error": "Invalid redraws_remaining"}
    if int(state["sync"]) < 0:
        return {"ok": false, "error": "Sync below zero"}

    var intent: Dictionary = state["enemy_intent"]
    if intent.is_empty() or not intent.has("id") or not intent.has("type") or not intent.has("target"):
        return {"ok": false, "error": "Enemy Intent is not fully visible"}

    return {"ok": true}

func _state_hash(state: Dictionary) -> String:
    var serial := {
        "turn": state["turn"],
        "draw": {},
        "discard": {},
        "hands": {},
        "formation": (state["formation"] as Array).map(func(v): return String(v)),
        "plays_remaining": state["plays_remaining"],
        "redraws_remaining": state["redraws_remaining"],
        "formation_free_remaining": state["formation_free_remaining"],
        "sync": state["sync"],
        "sync_generated_total": state["sync_generated_total"],
        "sync_spent_total": state["sync_spent_total"],
        "enemy_hp": state["enemy_hp"],
        "enemy_mark_source": String(state["enemy_mark_source"]),
        "ally_hp": _ally_hp_snapshot(state),
        "enemy_intent": _intent_snapshot(state["enemy_intent"]),
        "draw_rng_state": (state["draw_rng"] as RandomNumberGenerator).state,
        "ai_rng_state": (state["ai_rng"] as RandomNumberGenerator).state,
    }

    for character in CHARACTERS:
        serial["draw"][String(character)] = _card_ids(state["draw"][character])
        serial["discard"][String(character)] = _card_ids(state["discard"][character])
        serial["hands"][String(character)] = _card_ids(state["hands"][character])

    return JSON.stringify(serial)

func _card_ids(cards: Array) -> Array[String]:
    var out: Array[String] = []
    for raw in cards:
        out.append(String((raw as Dictionary)["id"]))
    return out

func _ally_hp_snapshot(state: Dictionary) -> Dictionary:
    var hp: Dictionary = state["ally_hp"]
    return {
        "char_bastion": hp[&"char_bastion"],
        "char_falcon": hp[&"char_falcon"],
        "char_loom": hp[&"char_loom"],
    }

func _intent_snapshot(intent: Dictionary) -> Dictionary:
    return {
        "id": String(intent.get("id", "")),
        "type": String(intent.get("type", "")),
        "target": String(intent.get("target", "")),
        "damage": int(intent.get("damage", 0)),
    }

func _rng_isolation_probe(seed: int) -> Dictionary:
    var state := _new_state(seed)
    var falcon_hand: Array = state["hands"][&"char_falcon"]

    var ai_before_redraw := (state["ai_rng"] as RandomNumberGenerator).state
    var draw_before_redraw := (state["draw_rng"] as RandomNumberGenerator).state

    var redraw_result := _apply_command(state, {
        "type": "redraw",
        "card_id": String((falcon_hand[0] as Dictionary)["id"]),
    })
    if not bool(redraw_result["ok"]):
        return {"pass": false, "stage": "redraw"}

    var ai_after_redraw := (state["ai_rng"] as RandomNumberGenerator).state
    var draw_after_redraw := (state["draw_rng"] as RandomNumberGenerator).state
    if ai_after_redraw != ai_before_redraw:
        return {"pass": false, "stage": "redraw_changed_ai"}

    # Drawing from an already shuffled pile is deterministic and does not need to
    # advance the draw RNG. Prove the streams with an explicit shuffle instead.
    var scratch := [0, 1, 2, 3, 4]
    var ai_before_shuffle := ai_after_redraw
    var draw_before_shuffle := draw_after_redraw
    _shuffle(scratch, state["draw_rng"])
    var ai_after_shuffle := (state["ai_rng"] as RandomNumberGenerator).state
    var draw_after_shuffle := (state["draw_rng"] as RandomNumberGenerator).state

    if draw_after_shuffle == draw_before_shuffle:
        return {"pass": false, "stage": "shuffle_did_not_advance_draw"}
    if ai_after_shuffle != ai_before_shuffle:
        return {"pass": false, "stage": "shuffle_changed_ai"}

    var draw_before_intent := draw_after_shuffle
    var ai_before_intent := ai_after_shuffle
    _roll_intent(state)
    var draw_after_intent := (state["draw_rng"] as RandomNumberGenerator).state
    var ai_after_intent := (state["ai_rng"] as RandomNumberGenerator).state

    return {
        "pass": draw_after_intent == draw_before_intent and ai_after_intent != ai_before_intent,
        "redraw_changed_draw": draw_after_redraw != draw_before_redraw,
        "redraw_changed_ai": ai_after_redraw != ai_before_redraw,
        "shuffle_changed_draw": draw_after_shuffle != draw_before_shuffle,
        "shuffle_changed_ai": ai_after_shuffle != ai_before_shuffle,
        "intent_changed_draw": draw_after_intent != draw_before_intent,
        "intent_changed_ai": ai_after_intent != ai_before_intent,
    }