extends SceneTree

const TABLE_PATH := "res://data/cards_table.tres"

func _init() -> void:
    var v := Engine.get_version_info()
    if int(v.get("major",-1)) != 4 or int(v.get("minor",-1)) != 7 or int(v.get("patch",-1)) != 1 or String(v.get("status","")) != "stable":
        push_error("Wrong engine: %s" % JSON.stringify(v))
        quit(2)
        return
    if not ResourceLoader.exists(TABLE_PATH):
        push_error("DataTable not found: %s" % TABLE_PATH)
        quit(3)
        return
    var table: DataTable = load(TABLE_PATH)
    if table.rows.size() != 100:
        push_error("Expected 100 rows, got %d" % table.rows.size())
        quit(4)
        return
    if table.row_order.size() != 100:
        push_error("row_order mismatch: %d" % table.row_order.size())
        quit(5)
        return
    var sample = table.get_row(&"card_bastion_000")
    if sample == null or sample.owner_character_id != &"char_bastion":
        push_error("Sample lookup mismatch")
        quit(6)
        return
    print("[P0:DataTables] sample.row_id after reload = '%s'" % String(sample.row_id))
    print("[P0:DataTables] PRECHECK PASS | rows=100")
    quit(0)
