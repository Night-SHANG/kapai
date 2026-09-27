extends SceneTree

const EventDefinitionClass := preload("res://scripts/event_definition.gd")
const FIXTURE := "res://fixtures/events.json"
const EVENT_DIR := "res://data/events"

func _init() -> void:
    var rows: Array = _load_json_array(FIXTURE)
    if rows.is_empty():
        push_error("No event fixtures found")
        quit(2)
        return

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVENT_DIR))

    for raw: Variant in rows:
        if not raw is Dictionary:
            push_error("Event fixture entry is not a Dictionary")
            quit(3)
            return
        var row: Dictionary = raw
        var event_id := String(row.get("id", ""))
        if event_id.is_empty():
            push_error("Event fixture has empty id")
            quit(4)
            return
        var definition = EventDefinitionClass.new()
        var payload: Dictionary = row.duplicate(true)
        var dialogue_source := String(payload.get("dialogue_resource", ""))
        payload["dialogue_resource"] = _runtime_dialogue_path(dialogue_source)
        definition.payload = payload
        var path := "%s/%s.tres" % [EVENT_DIR, event_id]
        var err := ResourceSaver.save(definition, path)
        if err != OK:
            push_error("Failed saving EventDefinition %s: %s" % [event_id, error_string(err)])
            quit(5)
            return

    print("[P0-5:YARD] EventDefinition resources built: %d" % rows.size())
    quit(0)

func _load_json_array(path: String) -> Array:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return []
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []

func _runtime_dialogue_path(source_path: String) -> String:
    return "res://data/dialogue/%s.tres" % source_path.get_file().get_basename()
