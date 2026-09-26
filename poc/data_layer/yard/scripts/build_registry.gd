extends SceneTree

const RegistryIO := preload("res://addons/yard/editor_only/registry_io.gd")
const FIXTURE := "res://fixtures/cards.json"
const REGISTRY_PATH := "res://data/cards_registry.tres"
const CARD_DIR := "res://data/cards"

func _init() -> void:
    if not Engine.is_editor_hint():
        push_error("build_registry.gd must run with --editor --headless")
        quit(2)
        return
    if FileAccess.file_exists(REGISTRY_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(REGISTRY_PATH))
    var create_err := RegistryIO.create_registry_file(REGISTRY_PATH)
    if create_err != OK:
        push_error("Failed creating registry: %s" % error_string(create_err))
        quit(3)
        return
    var registry: Registry = load(REGISTRY_PATH)
    var rows := _load_json_array(FIXTURE)
    for row: Dictionary in rows:
        var id := StringName(row["id"])
        var path := "%s/%s.tres" % [CARD_DIR,String(id)]
        if not ResourceLoader.exists(path):
            push_error("Resource missing after editor scan: %s" % path)
            quit(4)
            return
        var uid_int := ResourceLoader.get_resource_uid(path)
        var uid_text := StringName(ResourceUID.id_to_text(uid_int))
        var err := RegistryIO.add_entry(registry,uid_text,String(id))
        if err != OK:
            push_error("Registry add failed for %s: %s" % [id,error_string(err)])
            quit(5)
            return
    print("[P0:YARD] registry entries: %d" % registry.size())
    quit(0)

func _load_json_array(path: String) -> Array:
    var file := FileAccess.open(path,FileAccess.READ)
    if file == null: return []
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []
