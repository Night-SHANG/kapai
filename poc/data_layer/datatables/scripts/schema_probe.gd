extends SceneTree

const TABLE_PATH := "res://data/cards_table.tres"

func _init() -> void:
    var table: DataTable = load(TABLE_PATH)
    if table == null or table.rows.size() != 100:
        push_error("DataTable failed to load in schema probe")
        quit(2)
        return

    var sample = table.get_row(&"card_bastion_000")
    if sample == null:
        push_error("Sample row missing after schema addition")
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

    table.sanitize_all_rows()
    var err := ResourceSaver.save(table, TABLE_PATH)
    if err != OK:
        push_error("Failed saving sanitized table: %s" % error_string(err))
        quit(6)
        return

    print("[P0:DataTables] SCHEMA ADD PASS | old base_value=%d | new schema_probe=%d" % [sample.base_value, sample.get("schema_probe")])
    quit(0)
