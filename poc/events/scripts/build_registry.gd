extends SceneTree

const RegistryClass := preload("res://addons/yard/registry.gd")
const FIXTURE := "res://fixtures/events.json"
const EVENT_DIR := "res://data/events"
const REGISTRY_PATH := "res://data/events_registry.tres"

func _init() -> void:
    var rows: Array = _load_json_array(FIXTURE)
    if rows.is_empty():
        push_error("No event fixtures found")
        quit(2)
        return

    var uids_to_ids: Dictionary[StringName, StringName] = {}
    var ids_to_uids: Dictionary[StringName, StringName] = {}

    for raw: Variant in rows:
        var row: Dictionary = raw
        var event_id := StringName(String(row.get("id", "")))
        var path := "%s/%s.tres" % [EVENT_DIR, String(event_id)]
        if not ResourceLoader.exists(path):
            push_error("Event resource missing after import: %s" % path)
            quit(3)
            return
        var uid_int := ResourceLoader.get_resource_uid(path)
        if uid_int == ResourceUID.INVALID_ID:
            push_error("Event resource has no valid UID: %s" % path)
            quit(4)
            return
        var uid := StringName(ResourceUID.id_to_text(uid_int))
        if ids_to_uids.has(event_id) or uids_to_ids.has(uid):
            push_error("Duplicate event ID or resource UID: %s" % String(event_id))
            quit(5)
            return
        ids_to_uids[event_id] = uid
        uids_to_ids[uid] = event_id

    var registry = RegistryClass.new()
    registry.set("_version", 2)
    registry.set("_uids_to_string_ids", uids_to_ids)
    registry.set("_string_ids_to_uids", ids_to_uids)

    var err := ResourceSaver.save(registry, REGISTRY_PATH)
    if err != OK:
        push_error("Failed saving events registry: %s" % error_string(err))
        quit(6)
        return

    print("[P0-5:YARD] registry entries: %d" % registry.size())
    quit(0)

func _load_json_array(path: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return []
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []
