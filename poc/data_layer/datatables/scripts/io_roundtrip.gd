extends SceneTree

const DataTableIOClass := preload("res://addons/GodotDataTables/editor/utils/data_table_io.gd")
const TABLE_PATH := "res://data/cards_table.tres"
const RESULT_DIR := "res://result"
const JSON_PATH := "res://result/datatables_export.json"
const CSV_PATH := "res://result/datatables_export.csv"

func _init() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))

    var source: DataTable = load(TABLE_PATH)
    if source == null or source.rows.size() != 100:
        push_error("Source DataTable invalid")
        quit(2)
        return

    var json_err := DataTableIOClass.export_to_json(source, JSON_PATH)
    if json_err != OK:
        push_error("JSON export failed: %s" % error_string(json_err))
        quit(3)
        return

    var csv_err := DataTableIOClass.export_to_csv(source, CSV_PATH)
    if csv_err != OK:
        push_error("CSV export failed: %s" % error_string(csv_err))
        quit(4)
        return

    var json_table := DataTable.new()
    json_table.row_schema = source.row_schema.duplicate(true)
    var json_import_err := DataTableIOClass.import_from_json(json_table, JSON_PATH, true)
    if json_import_err != OK:
        push_error("JSON import failed: %s" % error_string(json_import_err))
        quit(5)
        return

    var csv_table := DataTable.new()
    csv_table.row_schema = source.row_schema.duplicate(true)
    var csv_import_err := DataTableIOClass.import_from_csv(csv_table, CSV_PATH, true)
    if csv_import_err != OK:
        push_error("CSV import failed: %s" % error_string(csv_import_err))
        quit(6)
        return

    if json_table.rows.size() != 100 or csv_table.rows.size() != 100:
        push_error("Round-trip row count mismatch JSON=%d CSV=%d" % [json_table.rows.size(), csv_table.rows.size()])
        quit(7)
        return

    var expected = source.get_row(&"card_bastion_000")
    var from_json = json_table.get_row(&"card_bastion_000")
    var from_csv = csv_table.get_row(&"card_bastion_000")

    if from_json == null or from_csv == null:
        push_error("Round-trip stable ID missing")
        quit(8)
        return

    if int(from_json.base_value) != int(expected.base_value) or int(from_csv.base_value) != int(expected.base_value):
        push_error("Round-trip base_value mismatch")
        quit(9)
        return

    if from_json.owner_character_id != expected.owner_character_id or from_csv.owner_character_id != expected.owner_character_id:
        push_error("Round-trip owner mismatch")
        quit(10)
        return

    print("[P0:DataTables] IO ROUNDTRIP PASS | JSON=100 | CSV=100")
    quit(0)
