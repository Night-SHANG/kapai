class_name P0GasEffectBridge
extends RefCounted

var asc: AbilitySystemComponent
var owner_id: StringName
var definitions: Dictionary = {}
var tracked: Dictionary = {}
var source_ids: Dictionary = {}

func _init(in_owner_id: StringName, in_asc: AbilitySystemComponent) -> void:
    owner_id = in_owner_id
    asc = in_asc
    asc.active_effect_added.connect(_on_active_effect_added)
    asc.active_effect_removed.connect(_on_active_effect_removed)

func register_effect(effect_id: StringName, effect: GameplayEffect) -> void:
    effect.resource_name = String(effect_id)
    definitions[effect_id] = effect

func apply(effect_id: StringName, source_id: StringName = &"") -> ActiveGameplayEffect:
    if not definitions.has(effect_id):
        return null
    var active := asc.apply_gameplay_effect(definitions[effect_id], asc)
    if active:
        tracked[effect_id] = active
        source_ids[effect_id] = source_id
    return active

func remove(effect_id: StringName) -> void:
    if not tracked.has(effect_id):
        return
    var active: ActiveGameplayEffect = tracked[effect_id]
    asc.remove_active_effect(active)

func has_tag(tag: StringName) -> bool:
    return asc.has_tag(tag)

func advance_turn() -> void:
    asc.advance_turn()

func get_stack_count(effect_id: StringName) -> int:
    if not tracked.has(effect_id):
        return 0
    return int((tracked[effect_id] as ActiveGameplayEffect).stack_count)

func get_remaining_turns(effect_id: StringName) -> int:
    if not tracked.has(effect_id):
        return 0
    return int((tracked[effect_id] as ActiveGameplayEffect).spec.remaining_turns)

func export_dto() -> Array[Dictionary]:
    var ids: Array = tracked.keys()
    ids.sort()
    var out: Array[Dictionary] = []
    for effect_id in ids:
        var active: ActiveGameplayEffect = tracked[effect_id]
        out.append({
            "effect_id": String(effect_id),
            "source_id": String(source_ids.get(effect_id, &"")),
            "stacks": int(active.stack_count),
            "remaining_turns": int(active.spec.remaining_turns),
        })
    return out

func restore_dto(dto: Array) -> void:
    clear_all()
    for raw in dto:
        var row: Dictionary = raw
        var effect_id := StringName(row["effect_id"])
        var stacks := int(row.get("stacks", 1))
        var active: ActiveGameplayEffect = null
        for i in range(stacks):
            active = apply(effect_id, StringName(row.get("source_id", "")))
        if active:
            active.spec.remaining_turns = int(row.get("remaining_turns", active.spec.remaining_turns))

func clear_all() -> void:
    var ids: Array = tracked.keys()
    for effect_id in ids:
        remove(effect_id)

func debug_dump() -> String:
    var parts: Array[String] = []
    for row in export_dto():
        parts.append("%s stacks=%d turns=%d source=%s" % [
            row["effect_id"],
            row["stacks"],
            row["remaining_turns"],
            row["source_id"],
        ])
    return " | ".join(parts)

func _on_active_effect_added(active: ActiveGameplayEffect) -> void:
    var effect := active.get_effect_def()
    if effect and not effect.resource_name.is_empty():
        tracked[StringName(effect.resource_name)] = active

func _on_active_effect_removed(active: ActiveGameplayEffect) -> void:
    var effect := active.get_effect_def()
    if not effect or effect.resource_name.is_empty():
        return
    var effect_id := StringName(effect.resource_name)
    if tracked.get(effect_id) == active:
        tracked.erase(effect_id)
        source_ids.erase(effect_id)
