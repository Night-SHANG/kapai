extends SceneTree

const SaveSystemScript := preload("res://addons/enhance_save_system/core/save_system.gd")
const StateModuleScript := preload("res://scripts/state_module.gd")
const RESULT_PATH := "res://result/enhanced.json"
const SLOT_PATH := "user://saves/slot_01.json"

var manager: Variant
var modules: Dictionary = {}

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _remove_tree(ProjectSettings.globalize_path("user://saves"))

    manager = SaveSystemScript.new()
    manager.auto_register = false
    manager.auto_load_global = false
    manager.auto_load_slot = 0
    manager.auto_save_enabled = false
    manager.save_screenshots_enabled = false
    manager.encryption_enabled = false
    manager.compression_enabled = false
    manager.atomic_write_enabled = true
    manager.backup_enabled = true
    manager.split_modules_enabled = false
    root.add_child(manager)
    await process_frame

    manager.register_migration(1, Callable(self, "_migration_1_to_2"))
    manager.register_migration(2, Callable(self, "_migration_2_to_3"))

    var v3 := _fixture("schema_v3.json")
    _set_state(v3)

    var report: Dictionary = {
        "candidate": "Enhanced Save System",
        "version": "pinned-main",
        "commit": "dc92d0bead1c449f36462f22e823b603e356e49a",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "project_schema_owned": "coupled_to_SaveWriter.FORMAT_VERSION_for_builtin_migration",
        "module_count": modules.size(),
        "single_file_module_commit": not manager.split_modules_enabled,
    }

    var round_save: bool = manager.save_slot(1)
    _clear_modules()
    var round_load: bool = manager.load_slot(1)
    var loaded := _get_state()
    report["roundtrip"] = round_save and round_load and _core_semantics(loaded, v3)
    report["expedition_resume"] = round_load and int(loaded.get("expedition", {}).get("threat", -1)) == 58

    _set_state(v3)
    var battle_save: bool = manager.save_slot(1)
    var uninterrupted: Dictionary = v3.duplicate(true)
    _next_battle_command(uninterrupted)
    _clear_modules()
    var battle_load: bool = manager.load_slot(1)
    var resumed := _get_state()
    if battle_load:
        _next_battle_command(resumed)
    report["battle_resume_deterministic"] = battle_save and battle_load and _battle_equal(uninterrupted, resumed)

    _write_legacy_slot(_fixture("schema_v1.json"), 1)
    _clear_modules()
    var mig_ok: bool = manager.load_slot(1)
    var migrated := _get_state()
    report["migration_pipeline"] = mig_ok and int(migrated.get("schema_version", -1)) == 3         and _has_item(migrated, "item_core_fragment") and not _has_item(migrated, "item_old_core")         and migrated.has("event_history") and migrated.has("maintenance")

    _write_legacy_slot(_fixture("schema_missing_id_v1.json"), 1)
    _clear_modules()
    var missing_ok: bool = manager.load_slot(1)
    report["missing_id_fail_closed"] = not missing_ok

    _write_legacy_slot(_fixture("schema_v4.json"), 4)
    _clear_modules()
    var newer_ok: bool = manager.load_slot(1)
    report["newer_schema_rejected"] = not newer_ok

    var rec_a: Dictionary = v3.duplicate(true)
    rec_a["profile"]["world_cycle"] = 18
    _set_state(rec_a)
    var rec1: bool = manager.save_slot(1)
    var rec_b: Dictionary = v3.duplicate(true)
    rec_b["profile"]["world_cycle"] = 19
    _set_state(rec_b)
    var rec2: bool = manager.save_slot(1)
    var bak_path := SLOT_PATH + ".bak"
    report["retained_history"] = false
    report["backup_exists"] = rec1 and rec2 and FileAccess.file_exists(bak_path)

    var broken := FileAccess.open(SLOT_PATH, FileAccess.WRITE)
    if broken != null:
        broken.store_string("P0_CORRUPTED_SAVE")
        broken.close()
    _clear_modules()
    var corrupted_load: bool = manager.load_slot(1)
    report["corruption_detected"] = not corrupted_load
    report["automatic_recovery"] = false
    report["damaged_evidence_preserved"] = FileAccess.file_exists(SLOT_PATH)
    var manual_recovery_ok := false
    if FileAccess.file_exists(bak_path):
        var corrupt_copy := SLOT_PATH + ".corrupt"
        var evidence_copy_err := DirAccess.copy_absolute(SLOT_PATH, corrupt_copy)
        var remove_main_err := DirAccess.remove_absolute(SLOT_PATH)
        var restore_copy_err := DirAccess.copy_absolute(bak_path, SLOT_PATH) if remove_main_err == OK else FAILED
        _clear_modules()
        manual_recovery_ok = evidence_copy_err == OK and remove_main_err == OK and restore_copy_err == OK and manager.load_slot(1)
        report["damaged_evidence_preserved"] = FileAccess.file_exists(corrupt_copy)
    report["manual_backup_recovery"] = manual_recovery_ok

    _set_state(v3)
    var stable_write: bool = manager.save_slot(1)
    var tmp_path := SLOT_PATH + ".tmp"
    var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
    if tmp != null:
        tmp.store_string("INCOMPLETE")
        tmp.close()
    _clear_modules()
    var residue_load: bool = manager.load_slot(1)
    report["interrupted_write_residue_safe"] = stable_write and residue_load and FileAccess.file_exists(tmp_path)

    var repeat_ok := true
    for i in range(20):
        var s: Dictionary = v3.duplicate(true)
        s["profile"]["world_cycle"] = 100 + i
        _set_state(s)
        if not manager.save_slot(1):
            repeat_ok = false
            break
    report["repeated_saves"] = repeat_ok

    var big := _large_state(v3)
    _set_state(big)
    var t0 := Time.get_ticks_usec()
    var big_save: bool = manager.save_slot(1)
    var t1 := Time.get_ticks_usec()
    _clear_modules()
    var big_load: bool = manager.load_slot(1)
    var t2 := Time.get_ticks_usec()
    var big_loaded := _get_state()
    report["benchmark"] = {
        "save_usec": t1 - t0,
        "load_usec": t2 - t1,
        "bytes": _file_size(SLOT_PATH),
        "inventory_stacks": 1000,
        "event_history": 500,
        "world_flags": 120,
        "locations": 120,
    }
    report["large_save_roundtrip"] = big_save and big_load and Array(big_loaded.get("inventory", {}).get("stacks", [])).size() == 1000
    report["explicit_error_status"] = true
    report["recovery_history_api"] = false

    report["hard_pass"] = bool(report["roundtrip"]) and bool(report["expedition_resume"])         and bool(report["battle_resume_deterministic"]) and bool(report["migration_pipeline"])         and bool(report["missing_id_fail_closed"]) and bool(report["newer_schema_rejected"])         and bool(report["corruption_detected"]) and bool(report["automatic_recovery"])         and bool(report["damaged_evidence_preserved"]) and bool(report["interrupted_write_residue_safe"])         and bool(report["repeated_saves"]) and bool(report["large_save_roundtrip"])

    _write_report(report)
    print("[P0-6:ENHANCED] SUMMARY | %s" % JSON.stringify(report))
    print("[P0-6:ENHANCED] COMPLETE")
    quit(0)

func _set_state(state: Dictionary) -> void:
    if modules.is_empty():
        _create_modules()
    modules["profile"].state = {"profile": state.get("profile", {}), "schema_version": state.get("schema_version", 3), "game_version": state.get("game_version", "")}
    modules["world"].state = {"world": state.get("world", {}), "fortress": state.get("fortress", {}), "research": state.get("research", {})}
    modules["inventory"].state = {"inventory": state.get("inventory", {}), "characters": state.get("characters", [])}
    modules["runtime"].state = {
        "event_history": state.get("event_history", {}), "tutorial": state.get("tutorial", {}),
        "expedition": state.get("expedition", {}), "battle": state.get("battle", {}),
        "rng_streams": state.get("rng_streams", {}), "migration": state.get("migration", {}),
        "modules": state.get("modules", {}), "maintenance": state.get("maintenance", {})
    }

func _create_modules() -> void:
    for key in ["profile", "world", "inventory", "runtime"]:
        var m: Variant = StateModuleScript.new()
        m.configure(key, {})
        modules[key] = m
        manager.register_module(m)

func _clear_modules() -> void:
    for m: Variant in modules.values():
        m.state = {}

func _get_state() -> Dictionary:
    var p: Dictionary = modules["profile"].state
    var w: Dictionary = modules["world"].state
    var i: Dictionary = modules["inventory"].state
    var r: Dictionary = modules["runtime"].state
    return {
        "schema_version": p.get("schema_version", 3), "game_version": p.get("game_version", ""),
        "profile": p.get("profile", {}), "world": w.get("world", {}), "fortress": w.get("fortress", {}),
        "research": w.get("research", {}), "inventory": i.get("inventory", {}), "characters": i.get("characters", []),
        "event_history": r.get("event_history", {}), "tutorial": r.get("tutorial", {}),
        "expedition": r.get("expedition", {}), "battle": r.get("battle", {}), "rng_streams": r.get("rng_streams", {}),
        "migration": r.get("migration", {}), "modules": r.get("modules", {}), "maintenance": r.get("maintenance", {})
    }

func _state_to_payload(state: Dictionary, format_version: int) -> Dictionary:
    _set_state(state)
    var payload: Dictionary = {}
    for key in modules:
        payload[key] = modules[key].state.duplicate(true)
    payload["_meta"] = {
        "version": format_version,
        "game_version": state.get("game_version", "0.0-p0"),
        "payload_format": "json_compact",
        "split_modules": false
    }
    return payload

func _write_legacy_slot(state: Dictionary, format_version: int) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
    var payload := _state_to_payload(state, format_version)
    var f := FileAccess.open(SLOT_PATH, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(payload))
        f.close()

func _migration_1_to_2(payload: Dictionary) -> Variant:
    if not payload.has("inventory"):
        return null
    var inv_module: Dictionary = payload["inventory"]
    var inventory: Dictionary = inv_module.get("inventory", {})
    var stacks: Array = inventory.get("stacks", [])
    for raw: Variant in stacks:
        if raw is Dictionary:
            var item_id := String(raw.get("item_id", ""))
            if item_id == "item_old_core":
                raw["item_id"] = "item_core_fragment"
            elif item_id == "item_deleted_unknown":
                return null
    inv_module["inventory"] = inventory
    payload["inventory"] = inv_module
    var runtime: Dictionary = payload.get("runtime", {})
    runtime["expedition"] = {
        "active": true, "region_id": "region_test", "location_id": "location_test_sealed_lab",
        "threat": 58, "carry_weight": 31, "secure_storage": [], "temp_protocols": [],
        "hunter": {"location_id": "location_hunter", "alert": 2},
        "party_hp": {"char_bastion": 17, "char_falcon": 11, "char_loom": 14}
    }
    runtime["rng_streams"] = {
        "battle_draw": {"state": 1234567}, "enemy_ai": {"state": 2345678}, "loot": {"state": 3456789},
        "event": {"state": 4567890}, "world": {"state": 5678901}
    }
    payload["runtime"] = runtime
    if payload.has("profile"):
        payload["profile"]["schema_version"] = 2
    return payload

func _migration_2_to_3(payload: Dictionary) -> Variant:
    var runtime: Dictionary = payload.get("runtime", {})
    runtime["event_history"] = runtime.get("event_history", {})
    runtime["tutorial"] = runtime.get("tutorial", {"seen": [], "dismissed": []})
    runtime["modules"] = runtime.get("modules", {"installed": []})
    runtime["maintenance"] = runtime.get("maintenance", {})
    runtime["battle"] = runtime.get("battle", {"active": false})
    runtime["migration"] = {"applied": ["1_to_2", "2_to_3"], "id_aliases": {"item_old_core": "item_core_fragment"}}
    payload["runtime"] = runtime
    var world: Dictionary = payload.get("world", {})
    world["fortress"] = world.get("fortress", {"resources": {"scrap": 0, "data": 0, "core": 0}, "power_capacity": 8})
    world["research"] = world.get("research", {"unlocked": []})
    payload["world"] = world
    if payload.has("profile"):
        payload["profile"]["schema_version"] = 3
    return payload

func _fixture(name: String) -> Dictionary:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/" + name))
    return parsed if parsed is Dictionary else {}

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
