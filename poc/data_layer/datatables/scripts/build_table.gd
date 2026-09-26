extends SceneTree

const CardRow := preload("res://scripts/card_row.gd")
const FIXTURE := "res://fixtures/cards.json"
const OUT_DIR := "res://data"
const TABLE_PATH := "res://data/cards_table.tres"

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
    var table := DataTable.new()
    table.row_schema = CardRow.new()
    for source: Dictionary in rows:
        var row := CardRow.new()
        row.owner_character_id = StringName(source["owner_character_id"])
        row.name_key = StringName(source["name_key"])
        row.description_key = StringName(source["description_key"])
        var tags: Array[StringName] = []
        for tag in source["tags"]: tags.append(StringName(tag))
        row.tags = tags
        row.base_value = int(source["base_value"])
        table.add_row(StringName(source["id"]),row)
    var err := ResourceSaver.save(table,TABLE_PATH)
    if err != OK:
        push_error("Failed saving DataTable: %s" % error_string(err))
        quit(4)
        return
    print("[P0:DataTables] wrote table rows: %d" % table.rows.size())
    quit(0)

func _load_json_array(path: String) -> Array:
    var file := FileAccess.open(path,FileAccess.READ)
    if file == null: return []
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Array else []

func _is_target_engine(v: Dictionary) -> bool:
    return int(v.get("major",-1)) == 4 and int(v.get("minor",-1)) == 7 and int(v.get("patch",-1)) == 1 and String(v.get("status","")) == "stable"
