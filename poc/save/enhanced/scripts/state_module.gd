extends ISaveModule
class_name P0StateModule

var module_key: String = "game"
var state: Dictionary = {}

func configure(key: String, initial: Dictionary) -> P0StateModule:
    module_key = key
    state = initial.duplicate(true)
    return self

func get_module_key() -> String:
    return module_key

func is_global() -> bool:
    return false

func collect_data() -> Dictionary:
    return state.duplicate(true)

func apply_data(data: Dictionary) -> void:
    state = data.duplicate(true)

func get_default_data() -> Dictionary:
    return {}
