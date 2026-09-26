extends SceneTree

const RegistryClass := preload("res://addons/yard/registry.gd")
const REGISTRY_PATH := "res://data/cards_registry.tres"
const OUT_PATH := "res://result/yard_export.json"

func _init() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://result"))
    var registry = ResourceLoader.load(REGISTRY_PATH)
    if registry == null or not registry.get_script() == RegistryClass:
        push_error("Registry failed to load for export")
        quit(2)
        return

    var output := {}
    for id: StringName in registry.get_all_string_ids():
        var resource = registry.load_entry(id)
        if resource == null:
            push_error("Cannot export dangling id: %s" % id)
            quit(3)
            return
        output[String(id)] = {
            "resource_path": resource.resource_path,
            "owner_character_id": String(resource.owner_character_id),
            "name_key": String(resource.name_key),
            "description_key": String(resource.description_key),
            "tags": Array(resource.tags).map(func(v): return String(v)),
            "base_value": int(resource.base_value),
        }

    var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Cannot create YARD migration export")
        quit(4)
        return
    file.store_string(JSON.stringify(output, "  "))
    file.close()

    if output.size() != 100:
        push_error("Export count mismatch: %d" % output.size())
        quit(5)
        return

    print("[P0:YARD] MIGRATION EXPORT PASS | rows=%d | %s" % [output.size(), OUT_PATH])
    quit(0)
