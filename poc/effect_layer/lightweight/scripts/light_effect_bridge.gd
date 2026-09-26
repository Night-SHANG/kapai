class_name P0LightEffectBridge
extends RefCounted

const Runtime := preload("res://scripts/effect_runtime.gd")

var owner_id: StringName
var runtime := Runtime.new()
var definitions: Dictionary = {}
var source_ids: Dictionary = {}
var guard: float = 10.0

func _init(in_owner_id: StringName) -> void:
    owner_id = in_owner_id

func register_effect(effect_id: StringName, definition: Dictionary) -> void:
    var copy := definition.duplicate(true)
    copy["id"] = effect_id
    definitions[effect_id] = copy

func apply(effect_id: StringName, source_id: StringName = &"") -> Dictionary:
    if not definitions.has(effect_id):
        return {}
    var state := runtime.apply(definitions[effect_id])
    if not state.is_empty():
        source_ids[effect_id] = source_id
        if effect_id == &"position_front":
            guard = 12.0
    return state

func remove(effect_id: StringName) -> void:
    runtime.remove(effect_id)
    source_ids.erase(effect_id)
    if effect_id == &"position_front":
        guard = 10.0

func has_tag(tag: StringName) -> bool:
    return runtime.has_tag(tag)

func advance_turn() -> void:
    runtime.advance_turn()

func export_dto() -> Array[Dictionary]:
    var ids: Array = runtime.active.keys()
    ids.sort()
    var out: Array[Dictionary] = []
    for effect_id in ids:
        var state: Dictionary = runtime.active[effect_id]
        out.append({
            "effect_id": String(effect_id),
            "source_id": String(source_ids.get(effect_id, &"")),
            "stacks": int(state["stacks"]),
            "remaining_turns": int(state["remaining_turns"]),
        })
    return out

func clear_all() -> void:
    for effect_id in runtime.active.keys().duplicate():
        remove(effect_id)

func restore_dto(dto: Array) -> void:
    clear_all()
    for raw in dto:
        var row: Dictionary = raw
        var effect_id := StringName(row["effect_id"])
        var stacks := int(row.get("stacks", 1))
        var state: Dictionary = {}
        for i in range(stacks):
            state = apply(effect_id, StringName(row.get("source_id", "")))
        if not state.is_empty():
            state["remaining_turns"] = int(row.get("remaining_turns", state["remaining_turns"]))
            runtime.active[effect_id] = state

func debug_dump() -> String:
    var parts: Array[String] = []
    for row in export_dto():
        parts.append("%s stacks=%d turns=%d source=%s" % [
            row["effect_id"], row["stacks"], row["remaining_turns"], row["source_id"]
        ])
    return " | ".join(parts)
