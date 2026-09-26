class_name P0CardRow
extends DataStructure

@export var owner_character_id: StringName
@export var name_key: StringName
@export var description_key: StringName
@export var tags: Array[StringName] = []
@export var base_value: int = 0

func _validate_row() -> PackedStringArray:
    var warnings := PackedStringArray()
    if owner_character_id.is_empty(): warnings.append("owner_character_id is empty")
    if name_key.is_empty(): warnings.append("name_key is empty")
    return warnings
