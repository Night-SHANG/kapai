extends SceneTree

const CardDefinition := preload("res://scripts/card_definition.gd")
const FIXTURE := "res://fixtures/cards.json"
const OUT_DIR := "res://data/cards"

func _init() -> void:
    var version := Engine.get_version_info()
    if not _is_target_engine(version):
        push_error("P0 requires Godot 4.7.1 stable")
        quit(2)
        return
    var rows := _load_json_array(FIXTURE)
    if rows.size() != 100:
        push_error("Expected 100 card fixtures, got %d" % rows.size())
        quit(3)
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
    for row: Dictionary in rows:
        var id := String(row["id"])
        var card := CardDefinition.new()
        card.owner_character_id = StringName(row["owner_character_id"])
        card.name_key = StringName(row["name_key"])
        card.description_key = StringName(row["description_key"])
        var tags: Array[StringName] = []
        for tag in row["tags"]: tags.append(StringName(tag))
        card.tags = tags
        card.base_value = int(row["base_value"])
        var path := "%s/%s.tres" % [OUT_DIR,id]
        var err := ResourceSaver.save(card,path)
        if err != OK:
            push_error("Failed saving %s: %s" % [path,error_string(err)])
            quit(4)
            return
    print("[P0:YARD] wrote 100 independent CardDefinition resources")
    quit(0)

func _load_json_array(path: String) -> Array:
    var file := FileAccess.open(path,FileAccess.READ)
    if file == null: return []
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []

func _is_target_engine(v: Dictionary) -> bool:
    return int(v.get("major",-1)) == 4 and int(v.get("minor",-1)) == 7 and int(v.get("patch",-1)) == 1 and String(v.get("status","")) == "stable"
