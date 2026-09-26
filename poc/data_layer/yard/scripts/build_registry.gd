extends SceneTree

const RegistryClass := preload("res://addons/yard/registry.gd")
const FIXTURE := "res://fixtures/cards.json"
const REGISTRY_PATH := "res://data/cards_registry.tres"
const CARD_DIR := "res://data/cards"

func _init() -> void:
    var rows := _load_json_array(FIXTURE)
    if rows.size() != 100:
        push_error("Expected 100 fixture rows, got %d" % rows.size())
        quit(2)
        return

    var uids_to_ids: Dictionary[StringName, StringName] = {}
    var ids_to_uids: Dictionary[StringName, StringName] = {}

    for row: Dictionary in rows:
        var id := StringName(row["id"])
        var path := "%s/%s.tres" % [CARD_DIR, String(id)]

        if not ResourceLoader.exists(path):
            push_error("Resource missing after editor import: %s" % path)
            quit(3)
            return

        var uid_int := ResourceLoader.get_resource_uid(path)
        if uid_int == ResourceUID.INVALID_ID:
            push_error("Resource has no valid UID: %s" % path)
            quit(4)
            return

        var uid := StringName(ResourceUID.id_to_text(uid_int))
        if uid == &"":
            push_error("Failed to convert UID for: %s" % path)
            quit(5)
            return

        if ids_to_uids.has(id):
            push_error("Duplicate stable ID: %s" % id)
            quit(6)
            return
        if uids_to_ids.has(uid):
            push_error("Duplicate resource UID: %s" % uid)
            quit(7)
            return

        ids_to_uids[id] = uid
        uids_to_ids[uid] = id

    var registry = RegistryClass.new()
    registry.set("_version", 2)
    registry.set("_uids_to_string_ids", uids_to_ids)
    registry.set("_string_ids_to_uids", ids_to_uids)

    var err := ResourceSaver.save(registry, REGISTRY_PATH)
    if err != OK:
        push_error("Failed saving registry: %s" % error_string(err))
        quit(8)
        return

    print("[P0:YARD] registry entries: %d" % registry.size())
    quit(0)

func _load_json_array(path: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot open fixture: %s" % path)
        return []
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []
