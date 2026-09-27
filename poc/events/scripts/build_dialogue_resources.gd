extends SceneTree

const EVENTS_FIXTURE := "res://fixtures/events.json"
const OUTPUT_DIR := "res://data/dialogue"

func _init() -> void:
    var events: Array = _load_json_array(EVENTS_FIXTURE)
    if events.is_empty():
        push_error("No events available for dialogue build")
        quit(2)
        return

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    var compiled_paths: Dictionary = {}

    for raw: Variant in events:
        if not raw is Dictionary:
            push_error("Event fixture entry is not a Dictionary")
            quit(3)
            return
        var event_def: Dictionary = raw
        var source_path := String(event_def.get("dialogue_resource", ""))
        if source_path.is_empty():
            push_error("Event has no dialogue_resource: %s" % event_def.get("id", ""))
            quit(4)
            return
        if compiled_paths.has(source_path):
            continue

        var source := FileAccess.get_file_as_string(source_path)
        if source.is_empty():
            push_error("Cannot read dialogue source: %s" % source_path)
            quit(5)
            return

        var result: DMCompilerResult = DMCompiler.compile_string(source, source_path)
        if not result.errors.is_empty():
            push_error("Dialogue compile failed for %s: %s" % [source_path, JSON.stringify(result.errors)])
            quit(6)
            return

        var resource := DialogueResource.new()
        resource.set_meta("dialogue_manager_version", "4.1.0")
        resource.using_states = result.using_states
        resource.cues = result.cues
        resource.first_cue = result.first_cue
        resource.character_names = result.character_names
        resource.lines = result.lines

        var output_path := runtime_path_for(source_path)
        var err := ResourceSaver.save(resource, output_path)
        if err != OK:
            push_error("Failed saving compiled DialogueResource %s: %s" % [output_path, error_string(err)])
            quit(7)
            return
        compiled_paths[source_path] = output_path

    print("[P0-5:DM] compiled DialogueResource files: %d" % compiled_paths.size())
    quit(0)

static func runtime_path_for(source_path: String) -> String:
    var file_name := source_path.get_file().get_basename()
    return "%s/%s.tres" % [OUTPUT_DIR, file_name]

func _load_json_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Array else []
