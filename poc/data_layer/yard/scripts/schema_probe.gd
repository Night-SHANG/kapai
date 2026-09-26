extends SceneTree

const RegistryClass := preload("res://addons/yard/registry.gd")
const REGISTRY_PATH := "res://data/cards_registry.tres"

func _init() -> void:
    var registry = ResourceLoader.load(REGISTRY_PATH)
    if registry == null or not registry.get_script() == RegistryClass:
        push_error("Registry failed to load in schema probe")
        quit(2)
        return

    var sample = registry.load_entry(&"card_bastion_000")
    if sample == null:
        push_error("Sample failed to load after schema addition")
        quit(3)
        return

    if int(sample.base_value) != 3:
        push_error("Existing field changed during schema addition: %s" % sample.base_value)
        quit(4)
        return

    if int(sample.get("schema_probe")) != 7:
        push_error("New schema field did not receive script default: %s" % sample.get("schema_probe"))
        quit(5)
        return

    print("[P0:YARD] SCHEMA ADD PASS | old base_value=%d | new schema_probe=%d" % [sample.base_value, sample.get("schema_probe")])
    quit(0)
