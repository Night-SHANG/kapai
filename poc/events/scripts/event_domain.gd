extends RefCounted
class_name P0EventDomain

const CONDITION_TYPES := [
    "HasCharacter",
    "PartyHasTag",
    "HasItem",
    "ItemCountAtLeast",
    "HasResearch",
    "ResourceAtLeast",
    "ThreatRange",
    "LocationState",
    "WorldFlag",
    "EventSeen",
    "EventNotSeen",
    "ALL",
    "ANY",
    "NOT",
]

const COMMAND_TYPES := [
    "AddResource",
    "RemoveResource",
    "AddItem",
    "RemoveItem",
    "ChangeThreat",
    "SetWorldFlag",
    "SetLocationState",
    "DiscoverLocation",
    "UnlockRoute",
    "DamageCharacter",
    "ApplyInjury",
    "StartBattle",
    "RestoreFacility",
    "UnlockArchive",
]

func is_event_available(event_def: Dictionary, state: Dictionary) -> bool:
    if not conditions_match(event_def.get("availability_conditions", []), state):
        return false

    var event_id := String(event_def.get("id", ""))
    var history: Dictionary = state.get("event_history", {})
    var entry: Dictionary = history.get(event_id, {})
    var times := int(entry.get("times", 0))
    var policy := String(event_def.get("repeat_policy", "repeat"))

    if policy == "once" and times > 0:
        return false

    if policy == "cooldown" and times > 0:
        var last_cycle := int(entry.get("last_cycle", -999999))
        var now := int(state.get("world_cycle", 0))
        var cooldown := int(event_def.get("cooldown_cycles", 0))
        if now - last_cycle < cooldown:
            return false

    return true

func get_available_options(event_def: Dictionary, state: Dictionary) -> Array[String]:
    var result: Array[String] = []
    if not is_event_available(event_def, state):
        return result
    for raw: Variant in event_def.get("options", []):
        var option: Dictionary = raw
        if conditions_match(option.get("conditions", []), state):
            result.append(String(option.get("option_id", "")))
    return result

func conditions_match(conditions: Array, state: Dictionary) -> bool:
    for raw: Variant in conditions:
        if not raw is Dictionary:
            return false
        if not condition_matches(raw, state):
            return false
    return true

func condition_matches(condition: Dictionary, state: Dictionary) -> bool:
    var condition_type := String(condition.get("type", ""))
    var args: Dictionary = condition.get("args", {})

    match condition_type:
        "HasCharacter":
            var party: Dictionary = state.get("party", {})
            return Array(party.get("character_ids", [])).has(String(args.get("character_id", "")))
        "PartyHasTag":
            var party: Dictionary = state.get("party", {})
            return Array(party.get("tags", [])).has(String(args.get("tag", "")))
        "HasItem":
            return _item_count(state, String(args.get("item_id", ""))) > 0
        "ItemCountAtLeast":
            return _item_count(state, String(args.get("item_id", ""))) >= int(args.get("count", 0))
        "HasResearch":
            var research: Dictionary = state.get("research", {})
            return bool(research.get(String(args.get("research_id", "")), false))
        "ResourceAtLeast":
            var resources: Dictionary = state.get("resources", {})
            return int(resources.get(String(args.get("resource_id", "")), 0)) >= int(args.get("amount", 0))
        "ThreatRange":
            var expedition: Dictionary = state.get("expedition", {})
            var threat := int(expedition.get("threat", 0))
            return threat >= int(args.get("min", -2147483648)) and threat <= int(args.get("max", 2147483647))
        "LocationState":
            return _location_value(state, String(args.get("location_id", "")), String(args.get("key", ""))) == args.get("value")
        "WorldFlag":
            var flags: Dictionary = state.get("world_flags", {})
            return flags.get(String(args.get("flag", "")), false) == args.get("value", true)
        "EventSeen":
            return _event_seen(state, String(args.get("event_id", "")))
        "EventNotSeen":
            return not _event_seen(state, String(args.get("event_id", "")))
        "ALL":
            return conditions_match(Array(args.get("conditions", [])), state)
        "ANY":
            for nested: Variant in Array(args.get("conditions", [])):
                if nested is Dictionary and condition_matches(nested, state):
                    return true
            return false
        "NOT":
            var nested: Variant = args.get("condition", {})
            return nested is Dictionary and not condition_matches(nested, state)
        _:
            return false

func preview_option(event_def: Dictionary, option_id: String, state: Dictionary) -> Dictionary:
    var option := _find_option(event_def, option_id)
    if option.is_empty():
        return {"ok": false, "error_code": "OPTION_NOT_FOUND", "changes": []}
    if not get_available_options(event_def, state).has(option_id):
        return {"ok": false, "error_code": "OPTION_NOT_AVAILABLE", "changes": []}

    var policy := String(option.get("preview_policy", "full"))
    if policy == "hidden":
        return {"ok": true, "error_code": "", "changes": [], "unknown": true}
    var commands: Array = option.get("commands", [])
    if policy == "partial":
        var partial: Array = []
        for raw: Variant in commands:
            var command: Dictionary = raw
            if bool(command.get("preview", false)):
                partial.append(command.duplicate(true))
        return {"ok": true, "error_code": "", "changes": partial, "unknown": true}
    return {"ok": true, "error_code": "", "changes": commands.duplicate(true), "unknown": false}

func resolve_option(event_def: Dictionary, option_id: String, state: Dictionary) -> Dictionary:
    var event_id := String(event_def.get("id", ""))
    if not is_event_available(event_def, state):
        return _result(false, "EVENT_NOT_AVAILABLE", "Event is not available", [])

    var option := _find_option(event_def, option_id)
    if option.is_empty():
        return _result(false, "OPTION_NOT_FOUND", "Option does not exist", [])
    if not conditions_match(option.get("conditions", []), state):
        return _result(false, "OPTION_NOT_AVAILABLE", "Option conditions are not satisfied", [])

    var draft: Dictionary = state.duplicate(true)
    var applied := _apply_commands(Array(option.get("commands", [])), draft, event_id, option_id)
    if not bool(applied.get("ok", false)):
        return applied

    var awaiting_battle := _has_command(Array(option.get("commands", [])), "StartBattle")
    if bool(option.get("completes_event", true)) and not awaiting_battle:
        _mark_event_history(draft, event_id)

    _commit_state(state, draft)
    applied["awaiting_battle"] = awaiting_battle
    return applied

func resolve_commands_transactional(commands: Array, state: Dictionary, event_id: String = "probe", option_id: String = "probe") -> Dictionary:
    var draft: Dictionary = state.duplicate(true)
    var applied := _apply_commands(commands, draft, event_id, option_id)
    if not bool(applied.get("ok", false)):
        return applied
    _commit_state(state, draft)
    return applied

func continue_after_battle(event_def: Dictionary, option_id: String, outcome: String, state: Dictionary) -> Dictionary:
    var event_id := String(event_def.get("id", ""))
    var option := _find_option(event_def, option_id)
    if option.is_empty():
        return _result(false, "OPTION_NOT_FOUND", "Battle continuation option does not exist", [])

    var expedition: Dictionary = state.get("expedition", {})
    var pending: Dictionary = expedition.get("pending_battle", {})
    if String(pending.get("event_id", "")) != event_id or String(pending.get("option_id", "")) != option_id:
        return _result(false, "BATTLE_CONTINUATION_MISMATCH", "No matching pending battle", [])

    var continuations: Dictionary = option.get("continuations", {})
    if not continuations.has(outcome):
        return _result(false, "BATTLE_OUTCOME_UNHANDLED", "Battle outcome has no continuation", [])

    var draft: Dictionary = state.duplicate(true)
    var draft_expedition: Dictionary = draft.get("expedition", {})
    draft_expedition["pending_battle"] = {}
    draft["expedition"] = draft_expedition

    var applied := _apply_commands(Array(continuations[outcome]), draft, event_id, option_id)
    if not bool(applied.get("ok", false)):
        return applied

    if bool(option.get("completes_event", true)):
        _mark_event_history(draft, event_id)

    _commit_state(state, draft)
    applied["battle_outcome"] = outcome
    return applied

func _apply_commands(commands: Array, draft: Dictionary, event_id: String, option_id: String) -> Dictionary:
    var changes: Array = []
    for raw: Variant in commands:
        if not raw is Dictionary:
            return _result(false, "INVALID_COMMAND", "Command is not a Dictionary", changes)
        var command: Dictionary = raw
        var command_result := _apply_command(command, draft, event_id, option_id)
        if not bool(command_result.get("ok", false)):
            command_result["changes"] = changes
            return command_result
        changes.append(command.duplicate(true))
    return _result(true, "", "", changes)

func _apply_command(command: Dictionary, draft: Dictionary, event_id: String, option_id: String) -> Dictionary:
    var command_type := String(command.get("type", ""))
    var args: Dictionary = command.get("args", {})
    if not COMMAND_TYPES.has(command_type):
        return _result(false, "UNKNOWN_COMMAND", "Unknown command type: %s" % command_type, [])

    match command_type:
        "AddResource":
            var resources: Dictionary = draft.get("resources", {})
            var resource_id := String(args.get("resource_id", ""))
            var amount := int(args.get("amount", 0))
            if amount < 0:
                return _result(false, "INVALID_AMOUNT", "Negative resource add", [])
            resources[resource_id] = int(resources.get(resource_id, 0)) + amount
            draft["resources"] = resources
        "RemoveResource":
            var resources: Dictionary = draft.get("resources", {})
            var resource_id := String(args.get("resource_id", ""))
            var amount := int(args.get("amount", 0))
            if amount <= 0 or int(resources.get(resource_id, 0)) < amount:
                return _result(false, "RESOURCE_INSUFFICIENT", "Resource removal cannot be satisfied", [])
            resources[resource_id] = int(resources.get(resource_id, 0)) - amount
            draft["resources"] = resources
        "AddItem":
            var inventory: Dictionary = draft.get("inventory", {})
            var item_id := String(args.get("item_id", ""))
            var count := int(args.get("count", 0))
            if count <= 0:
                return _result(false, "INVALID_AMOUNT", "Item add count must be positive", [])
            inventory[item_id] = int(inventory.get(item_id, 0)) + count
            draft["inventory"] = inventory
        "RemoveItem":
            var inventory: Dictionary = draft.get("inventory", {})
            var item_id := String(args.get("item_id", ""))
            var count := int(args.get("count", 0))
            if count <= 0 or int(inventory.get(item_id, 0)) < count:
                return _result(false, "ITEM_INSUFFICIENT", "Item removal cannot be satisfied", [])
            inventory[item_id] = int(inventory.get(item_id, 0)) - count
            draft["inventory"] = inventory
        "ChangeThreat":
            var expedition: Dictionary = draft.get("expedition", {})
            expedition["threat"] = maxi(0, int(expedition.get("threat", 0)) + int(args.get("amount", 0)))
            draft["expedition"] = expedition
        "SetWorldFlag":
            var flags: Dictionary = draft.get("world_flags", {})
            flags[String(args.get("flag", ""))] = args.get("value", true)
            draft["world_flags"] = flags
        "SetLocationState":
            var locations: Dictionary = draft.get("locations", {})
            var location_id := String(args.get("location_id", ""))
            if not locations.has(location_id):
                return _result(false, "LOCATION_NOT_FOUND", "Location state does not exist", [])
            var location: Dictionary = locations[location_id]
            var local_flags: Dictionary = location.get("local_flags", {})
            local_flags[String(args.get("key", ""))] = args.get("value")
            location["local_flags"] = local_flags
            locations[location_id] = location
            draft["locations"] = locations
        "DiscoverLocation":
            _append_unique(draft, "discovered_locations", String(args.get("location_id", "")))
        "UnlockRoute":
            _append_unique(draft, "unlocked_routes", String(args.get("route_id", "")))
        "DamageCharacter":
            var expedition: Dictionary = draft.get("expedition", {})
            var hp: Dictionary = expedition.get("current_hp_by_character", {})
            var character_id := String(args.get("character_id", ""))
            if not hp.has(character_id):
                return _result(false, "CHARACTER_NOT_IN_EXPEDITION", "Character HP state missing", [])
            hp[character_id] = maxi(0, int(hp[character_id]) - int(args.get("amount", 0)))
            expedition["current_hp_by_character"] = hp
            draft["expedition"] = expedition
        "ApplyInjury":
            var expedition: Dictionary = draft.get("expedition", {})
            var injuries: Dictionary = expedition.get("injuries", {})
            injuries[String(args.get("character_id", ""))] = String(args.get("injury_id", "injury_test"))
            expedition["injuries"] = injuries
            draft["expedition"] = expedition
        "StartBattle":
            var expedition: Dictionary = draft.get("expedition", {})
            var existing: Dictionary = expedition.get("pending_battle", {})
            if not existing.is_empty():
                return _result(false, "BATTLE_ALREADY_PENDING", "Cannot start a second pending battle", [])
            expedition["pending_battle"] = {
                "encounter_id": String(args.get("encounter_id", "")),
                "event_id": event_id,
                "option_id": option_id,
            }
            draft["expedition"] = expedition
        "RestoreFacility":
            _append_unique(draft, "restored_facilities", String(args.get("facility_id", "")))
        "UnlockArchive":
            _append_unique(draft, "archives", String(args.get("archive_id", "")))

    return _result(true, "", "", [])

func _find_option(event_def: Dictionary, option_id: String) -> Dictionary:
    for raw: Variant in event_def.get("options", []):
        if raw is Dictionary:
            var option: Dictionary = raw
            if String(option.get("option_id", "")) == option_id:
                return option
    return {}

func _has_command(commands: Array, command_type: String) -> bool:
    for raw: Variant in commands:
        if raw is Dictionary and String(raw.get("type", "")) == command_type:
            return true
    return false

func _event_seen(state: Dictionary, event_id: String) -> bool:
    var history: Dictionary = state.get("event_history", {})
    var entry: Dictionary = history.get(event_id, {})
    return int(entry.get("times", 0)) > 0

func _mark_event_history(state: Dictionary, event_id: String) -> void:
    var history: Dictionary = state.get("event_history", {})
    var entry: Dictionary = history.get(event_id, {})
    entry["times"] = int(entry.get("times", 0)) + 1
    entry["last_cycle"] = int(state.get("world_cycle", 0))
    history[event_id] = entry
    state["event_history"] = history

func _item_count(state: Dictionary, item_id: String) -> int:
    var inventory: Dictionary = state.get("inventory", {})
    return int(inventory.get(item_id, 0))

func _location_value(state: Dictionary, location_id: String, key: String) -> Variant:
    var locations: Dictionary = state.get("locations", {})
    if not locations.has(location_id):
        return null
    var location: Dictionary = locations[location_id]
    if key == "state":
        return location.get("state")
    var local_flags: Dictionary = location.get("local_flags", {})
    return local_flags.get(key)

func _append_unique(state: Dictionary, key: String, value: String) -> void:
    var values: Array = state.get(key, [])
    if not values.has(value):
        values.append(value)
    state[key] = values

func _commit_state(target: Dictionary, draft: Dictionary) -> void:
    target.clear()
    for key: Variant in draft.keys():
        target[key] = draft[key]

func _result(ok: bool, error_code: String, message: String, changes: Array) -> Dictionary:
    return {
        "ok": ok,
        "error_code": error_code,
        "message": message,
        "changes": changes,
    }
