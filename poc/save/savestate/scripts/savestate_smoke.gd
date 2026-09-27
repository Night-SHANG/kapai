extends SceneTree

const ManagerScript := preload("res://addons/savestate/save_manager.gd")
const RESULT_PATH := "res://result/savestate.json"

var manager: Variant

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var root_path := "user://p0_savestate"
    _remove_tree(ProjectSettings.globalize_path(root_path))
    ProjectSettings.set_setting("savestate/current_version", 3)

    manager = ManagerScript.new()
    manager.save_root = root_path
    manager.use_json = false
    manager.backup_on_commit = true
    manager.generation_retention = 5
    root.add_child(manager)
    await process_frame
    manager.set_schema_migrations([Callable(self, "_migrate_1_to_2"), Callable(self, "_migrate_2_to_3")])

    var report: Dictionary = {
        "candidate": "SaveState Lite",
        "version": "v2.0.0",
        "commit": "22b912aebbc6b52b3b31f74d3d83fec48b53870c",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "project_schema_owned": true,
    }

    var v3 := _fixture("schema_v3.json")
    var round_save: Variant = manager.save_generation_sync(&"roundtrip", v3)
    var round_load: Variant = manager.load_generation_sync(&"roundtrip", false, false)
    report["roundtrip"] = _ok(round_save) and _ok(round_load) and _core_semantics(round_load.data, v3)
    report["expedition_resume"] = _ok(round_load) and int(round_load.data.get("expedition", {}).get("threat", -1)) == 58

    var uninterrupted: Dictionary = v3.duplicate(true)
    _next_battle_command(uninterrupted)
    var battle_save: Variant = manager.save_generation_sync(&"battle_resume", v3)
    var battle_load: Variant = manager.load_generation_sync(&"battle_resume", false, false)
    var resumed: Dictionary = battle_load.data.duplicate(true) if _ok(battle_load) else {}
    if not resumed.is_empty():
        _next_battle_command(resumed)
    report["battle_resume_deterministic"] = _ok(battle_save) and _ok(battle_load) and _battle_equal(uninterrupted, resumed)

    ProjectSettings.set_setting("savestate/current_version", 1)
    var v1 := _fixture("schema_v1.json")
    var mig_save: Variant = manager.save_generation_sync(&"migration", v1)
    ProjectSettings.set_setting("savestate/current_version", 3)
    manager.set_schema_migrations([Callable(self, "_migrate_1_to_2"), Callable(self, "_migrate_2_to_3")])
    var mig_load: Variant = manager.load_generation_sync(&"migration", false, false)
    report["migration_pipeline"] = _ok(mig_save) and _ok(mig_load) and int(mig_load.data.get("schema_version", -1)) == 3         and _has_item(mig_load.data, "item_core_fragment") and not _has_item(mig_load.data, "item_old_core")         and mig_load.data.has("event_history") and mig_load.data.has("maintenance")

    ProjectSettings.set_setting("savestate/current_version", 1)
    var missing := _fixture("schema_missing_id_v1.json")
    var missing_save: Variant = manager.save_generation_sync(&"missing_id", missing)
    ProjectSettings.set_setting("savestate/current_version", 3)
    var missing_load: Variant = manager.load_generation_sync(&"missing_id", false, false)
    report["missing_id_fail_closed"] = _ok(missing_save) and not _ok(missing_load) and String(missing_load.get("status")).contains("migration")

    ProjectSettings.set_setting("savestate/current_version", 4)
    var v4 := _fixture("schema_v4.json")
    var newer_save: Variant = manager.save_generation_sync(&"newer", v4)
    ProjectSettings.set_setting("savestate/current_version", 3)
    var newer_load: Variant = manager.load_generation_sync(&"newer", false, false)
    report["newer_schema_rejected"] = _ok(newer_save) and not _ok(newer_load) and String(newer_load.get("status")) == "newer_schema"

    var r1: Dictionary = v3.duplicate(true)
    r1["profile"]["world_cycle"] = 18
    var r2: Dictionary = v3.duplicate(true)
    r2["profile"]["world_cycle"] = 19
    var rec1: Variant = manager.save_generation_sync(&"recovery", r1)
    var rec2: Variant = manager.save_generation_sync(&"recovery", r2)
    var scan: Dictionary = SaveStateGenerationStore.scan(manager.save_root, "recovery")
    var files: Array = scan.get("files", [])
    report["retained_history"] = _ok(rec1) and _ok(rec2) and files.size() >= 2
    var corrupt_path := ""
    if not files.is_empty():
        corrupt_path = String(files[0].get("path", ""))
        var broken := FileAccess.open(corrupt_path, FileAccess.WRITE)
        if broken != null:
            broken.store_string("P0_CORRUPTED_GENERATION")
            broken.close()
    var bad_load: Variant = manager.load_generation_sync(&"recovery", false, false)
    var recovered: Variant = manager.load_generation_sync(&"recovery", true, false)
    report["corruption_detected"] = not _ok(bad_load)
    report["automatic_recovery"] = _ok(recovered) and int(recovered.data.get("profile", {}).get("world_cycle", -1)) == 18
    report["damaged_evidence_preserved"] = not corrupt_path.is_empty() and FileAccess.file_exists(corrupt_path)

    var interrupted: Variant = manager.save_generation_sync(&"interrupted", v3)
    var iscan: Dictionary = SaveStateGenerationStore.scan(manager.save_root, "interrupted")
    var ifiles: Array = iscan.get("files", [])
    var residue_ok := false
    if _ok(interrupted) and not ifiles.is_empty():
        var valid_path := String(ifiles[0].get("path", ""))
        var partial_path := valid_path.trim_suffix(".ssv") + ".partial"
        var partial := FileAccess.open(partial_path, FileAccess.WRITE)
        if partial != null:
            partial.store_string("INCOMPLETE")
            partial.close()
        var after_residue: Variant = manager.load_generation_sync(&"interrupted", false, false)
        residue_ok = _ok(after_residue) and FileAccess.file_exists(partial_path)
    report["interrupted_write_residue_safe"] = residue_ok

    var repeat_ok := true
    for i in range(20):
        var s: Dictionary = v3.duplicate(true)
        s["profile"]["world_cycle"] = 100 + i
        var rr: Variant = manager.save_generation_sync(&"repeat", s)
        if not _ok(rr):
            repeat_ok = false
            break
    report["repeated_saves"] = repeat_ok

    var big := _large_state(v3)
    var t0 := Time.get_ticks_usec()
    var big_save: Variant = manager.save_generation_sync(&"benchmark", big)
    var t1 := Time.get_ticks_usec()
    var big_load: Variant = manager.load_generation_sync(&"benchmark", false, false)
    var t2 := Time.get_ticks_usec()
    report["benchmark"] = {
        "save_usec": t1 - t0,
        "load_usec": t2 - t1,
        "bytes": _file_size(String(big_save.get("path"))) if _ok(big_save) else -1,
        "inventory_stacks": 1000,
        "event_history": 500,
        "world_flags": 120,
        "locations": 120,
    }
    report["large_save_roundtrip"] = _ok(big_save) and _ok(big_load) and Array(big_load.data.get("inventory", {}).get("stacks", [])).size() == 1000

    report["explicit_error_status"] = not _ok(newer_load) and not String(newer_load.get("status")).is_empty()
    report["recovery_history_api"] = manager.has_method("list_generations") and manager.has_method("recover_generation_sync")
    report["debug_json_export_api"] = manager.has_method("export_save_file_to_json")

    report["hard_pass"] = bool(report["roundtrip"]) and bool(report["expedition_resume"])         and bool(report["battle_resume_deterministic"]) and bool(report["migration_pipeline"])         and bool(report["missing_id_fail_closed"]) and bool(report["newer_schema_rejected"])         and bool(report["retained_history"]) and bool(report["corruption_detected"])         and bool(report["automatic_recovery"]) and bool(report["damaged_evidence_preserved"])         and bool(report["interrupted_write_residue_safe"]) and bool(report["repeated_saves"])         and bool(report["large_save_roundtrip"])

    _write_report(report)
    print("[P0-6:SAVESTATE] SUMMARY | %s" % JSON.stringify(report))
    if not bool(report["hard_pass"]):
        push_error("SaveState candidate failed one or more P0-6 hard requirements")
        quit(20)
        return
    print("[P0-6:SAVESTATE] PASS")
    quit(0)

func _migrate_1_to_2(data: Dictionary) -> bool:
    var inventory: Dictionary = data.get("inventory", {})
    var stacks: Array = inventory.get("stacks", [])
    for raw: Variant in stacks:
        if raw is Dictionary:
            var stack: Dictionary = raw
            var item_id := String(stack.get("item_id", ""))
            if item_id == "item_old_core":
                stack["item_id"] = "item_core_fragment"
            elif item_id == "item_deleted_unknown":
                return false
    data["inventory"] = inventory
    data["expedition"] = {
        "active": true, "region_id": "region_test", "location_id": "location_test_sealed_lab",
        "threat": 58, "carry_weight": 31, "secure_storage": [], "temp_protocols": [],
        "hunter": {"location_id": "location_hunter", "alert": 2},
        "party_hp": {"char_bastion": 17, "char_falcon": 11, "char_loom": 14}
    }
    data["rng_streams"] = {
        "battle_draw": {"state": 1234567}, "enemy_ai": {"state": 2345678}, "loot": {"state": 3456789},
        "event": {"state": 4567890}, "world": {"state": 5678901}
    }
    data["schema_version"] = 2
    return true

func _migrate_2_to_3(data: Dictionary) -> bool:
    data["fortress"] = data.get("fortress", {"resources": {"scrap": 0, "data": 0, "core": 0}, "power_capacity": 8})
    data["research"] = data.get("research", {"unlocked": []})
    data["event_history"] = data.get("event_history", {})
    data["tutorial"] = data.get("tutorial", {"seen": [], "dismissed": []})
    data["modules"] = data.get("modules", {"installed": []})
    data["maintenance"] = data.get("maintenance", {})
    data["battle"] = data.get("battle", {"active": false})
    data["migration"] = {"applied": ["1_to_2", "2_to_3"], "id_aliases": {"item_old_core": "item_core_fragment"}}
    data["schema_version"] = 3
    return true

func _fixture(name: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/" + name))
    return parsed if parsed is Dictionary else {}

func _ok(result: Variant) -> bool:
    return result != null and bool(result.get("ok"))

func _has_item(state: Dictionary, item_id: String) -> bool:
    for raw: Variant in state.get("inventory", {}).get("stacks", []):
        if raw is Dictionary and String(raw.get("item_id", "")) == item_id:
            return true
    return false

func _core_semantics(a: Dictionary, b: Dictionary) -> bool:
    return int(a.get("schema_version", -1)) == int(b.get("schema_version", -2))         and int(a.get("expedition", {}).get("threat", -1)) == int(b.get("expedition", {}).get("threat", -2))         and int(a.get("battle", {}).get("turn", -1)) == int(b.get("battle", {}).get("turn", -2))         and Array(a.get("inventory", {}).get("stacks", [])).size() == Array(b.get("inventory", {}).get("stacks", [])).size()

func _next_battle_command(state: Dictionary) -> void:
    var old_state: int = int(state["rng_streams"]["battle_draw"]["state"])
    var next_state: int = int((old_state * 1103515245 + 12345) & 0x7fffffff)
    state["rng_streams"]["battle_draw"]["state"] = next_state
    var damage: int = 1 + (next_state % 5)
    state["battle"]["enemy_hp"]["enemy_guard_a"] = int(state["battle"]["enemy_hp"]["enemy_guard_a"]) - damage

func _battle_equal(a: Dictionary, b: Dictionary) -> bool:
    if b.is_empty():
        return false
    return int(a["rng_streams"]["battle_draw"]["state"]) == int(b["rng_streams"]["battle_draw"]["state"])         and int(a["battle"]["enemy_hp"]["enemy_guard_a"]) == int(b["battle"]["enemy_hp"]["enemy_guard_a"])

func _large_state(base: Dictionary) -> Dictionary:
    var s: Dictionary = base.duplicate(true)
    var flags: Dictionary = {}
    var locations: Dictionary = {}
    var history: Dictionary = {}
    var stacks: Array = []
    for i in range(120):
        flags["flag_%03d" % i] = i % 2 == 0
        locations["location_%03d" % i] = {"state": "cleared" if i % 3 == 0 else "discovered", "local_flags": {"x": i}}
    for i in range(500):
        history["event_%04d" % i] = {"times": 1 + (i % 4), "last_cycle": i % 50}
    for i in range(1000):
        stacks.append({"item_id": "item_test_%04d" % (i % 100), "count": 1 + (i % 20), "instance_id": i})
    s["world"]["flags"] = flags
    s["world"]["locations"] = locations
    s["event_history"] = history
    s["inventory"]["stacks"] = stacks
    return s

func _file_size(path: String) -> int:
    if path.is_empty():
        return -1
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return -1
    var n := f.get_length()
    f.close()
    return n

func _write_report(report: Dictionary) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://result"))
    var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(report, "\t") + "\n")
        f.close()

func _remove_tree(path: String) -> void:
    if not DirAccess.dir_exists_absolute(path):
        return
    var d := DirAccess.open(path)
    if d == null:
        return
    d.list_dir_begin()
    var name := d.get_next()
    while not name.is_empty():
        var child := path.path_join(name)
        if d.current_is_dir():
            _remove_tree(child)
        else:
            DirAccess.remove_absolute(child)
        name = d.get_next()
    d.list_dir_end()
    DirAccess.remove_absolute(path)
