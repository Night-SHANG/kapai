class_name P0EffectRuntime
extends RefCounted

var active: Dictionary = {}
var tags: Dictionary = {}

func has_tag(tag: StringName) -> bool:
    return int(tags.get(tag, 0)) > 0

func _add_tag(tag: StringName) -> void:
    tags[tag] = int(tags.get(tag, 0)) + 1

func _remove_tag(tag: StringName) -> void:
    var count := int(tags.get(tag, 0)) - 1
    if count <= 0:
        tags.erase(tag)
    else:
        tags[tag] = count

func apply(def: Dictionary) -> Dictionary:
    for required: StringName in def.get("require_all_tags", []):
        if not has_tag(required):
            return {}

    for cleanse_tag: StringName in def.get("remove_effects_with_tags", []):
        cleanse_by_tag(cleanse_tag)

    var id: StringName = def["id"]
    var max_stacks := int(def.get("max_stacks", 1))

    if active.has(id):
        var state: Dictionary = active[id]
        if max_stacks > 0 and int(state["stacks"]) >= max_stacks:
            var overflow_tag: StringName = def.get("overflow_tag", &"")
            if overflow_tag != &"":
                _add_tag(overflow_tag)
            return state

        state["stacks"] = int(state["stacks"]) + 1
        state["remaining_turns"] = int(def.get("duration_turns", state["remaining_turns"]))
        active[id] = state
        return state

    var state := {
        "id": id,
        "tags": def.get("granted_tags", []).duplicate(),
        "stacks": 1,
        "remaining_turns": int(def.get("duration_turns", 0)),
    }
    active[id] = state
    for tag: StringName in state["tags"]:
        _add_tag(tag)
    return state

func cleanse_by_tag(tag: StringName) -> void:
    var ids := active.keys()
    for id in ids:
        var state: Dictionary = active[id]
        if tag in state["tags"]:
            remove(id)

func remove(id: StringName) -> void:
    if not active.has(id):
        return
    var state: Dictionary = active[id]
    for tag: StringName in state["tags"]:
        _remove_tag(tag)
    active.erase(id)

func advance_turn() -> void:
    var ids := active.keys()
    for id in ids:
        var state: Dictionary = active[id]
        var remaining := int(state["remaining_turns"])
        if remaining <= 0:
            continue
        remaining -= 1
        if remaining <= 0:
            remove(id)
        else:
            state["remaining_turns"] = remaining
            active[id] = state
