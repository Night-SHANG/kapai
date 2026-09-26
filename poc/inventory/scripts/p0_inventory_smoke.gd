extends SceneTree

const EPS := 0.0001

class LightweightInventory:
    var defs: Dictionary
    var max_weight: float
    var stacks: Array[Dictionary] = []
    var slot_states: Dictionary = {}

    func _init(p_defs: Dictionary, p_max_weight: float) -> void:
        defs = p_defs
        max_weight = p_max_weight

    func definition(item_id: String) -> Dictionary:
        return defs.get(item_id, {})

    func current_weight() -> float:
        var total := 0.0
        for stack: Dictionary in stacks:
            var defn: Dictionary = definition(String(stack["item_id"]))
            total += float(defn.get("weight", 0.0)) * int(stack["count"])
        return total

    func total_count(item_id: String) -> int:
        var total := 0
        for stack: Dictionary in stacks:
            if String(stack["item_id"]) == item_id:
                total += int(stack["count"])
        return total

    func can_add(item_id: String, count: int) -> bool:
        if count <= 0 or not defs.has(item_id):
            return false
        var unit_weight := float(definition(item_id).get("weight", 0.0))
        return current_weight() + unit_weight * count <= max_weight + EPS

    func add(item_id: String, count: int, secure: bool = false) -> bool:
        if not can_add(item_id, count):
            return false
        var defn: Dictionary = definition(item_id)
        var max_stack := maxi(1, int(defn.get("max_stack", 1)))
        var remaining := count
        for stack: Dictionary in stacks:
            if remaining <= 0:
                break
            if String(stack["item_id"]) != item_id or bool(stack.get("secure", false)) != secure:
                continue
            var room := max_stack - int(stack["count"])
            if room <= 0:
                continue
            var moved := mini(room, remaining)
            stack["count"] = int(stack["count"]) + moved
            remaining -= moved
        while remaining > 0:
            var amount := mini(max_stack, remaining)
            stacks.append({
                "item_id": item_id,
                "count": amount,
                "instance_id": "",
                "overrides": {},
                "secure": secure,
            })
            remaining -= amount
        return true

    func split_stack(index: int, new_stack_size: int) -> bool:
        if index < 0 or index >= stacks.size() or new_stack_size <= 0:
            return false
        var source: Dictionary = stacks[index]
        var source_count := int(source["count"])
        if new_stack_size >= source_count:
            return false
        source["count"] = source_count - new_stack_size
        var created: Dictionary = source.duplicate(true)
        created["count"] = new_stack_size
        stacks.append(created)
        return true

    func merge_stacks(dst_index: int, src_index: int) -> bool:
        if dst_index == src_index or dst_index < 0 or src_index < 0:
            return false
        if dst_index >= stacks.size() or src_index >= stacks.size():
            return false
        var dst: Dictionary = stacks[dst_index]
        var src: Dictionary = stacks[src_index]
        if String(dst["item_id"]) != String(src["item_id"]):
            return false
        if bool(dst.get("secure", false)) != bool(src.get("secure", false)):
            return false
        var max_stack := maxi(1, int(definition(String(dst["item_id"])).get("max_stack", 1)))
        var room := max_stack - int(dst["count"])
        if room <= 0:
            return false
        var moved := mini(room, int(src["count"]))
        dst["count"] = int(dst["count"]) + moved
        src["count"] = int(src["count"]) - moved
        if int(src["count"]) == 0:
            stacks.remove_at(src_index)
        return moved > 0

    func remove_count(item_id: String, count: int) -> bool:
        if count <= 0 or total_count(item_id) < count:
            return false
        var remaining := count
        for i in range(stacks.size() - 1, -1, -1):
            if remaining <= 0:
                break
            var stack: Dictionary = stacks[i]
            if String(stack["item_id"]) != item_id or bool(stack.get("secure", false)):
                continue
            var take := mini(remaining, int(stack["count"]))
            stack["count"] = int(stack["count"]) - take
            remaining -= take
            if int(stack["count"]) == 0:
                stacks.remove_at(i)
        return remaining == 0

    func transfer_to(target: LightweightInventory, item_id: String, count: int) -> bool:
        if total_count(item_id) < count or not target.can_add(item_id, count):
            return false
        if not remove_count(item_id, count):
            return false
        if target.add(item_id, count):
            return true
        add(item_id, count)
        return false

    func discard(item_id: String, count: int) -> bool:
        if bool(definition(item_id).get("key_item", false)):
            return false
        return remove_count(item_id, count)

    func equip_module(slot_id: String, required_tag: String, item_id: String) -> bool:
        if total_count(item_id) < 1:
            return false
        var tags: Array = definition(item_id).get("slot_tags", [])
        if not tags.has(required_tag) or slot_states.has(slot_id):
            return false
        if not remove_count(item_id, 1):
            return false
        slot_states[slot_id] = item_id
        return true

    func unequip_module(slot_id: String) -> bool:
        if not slot_states.has(slot_id):
            return false
        var item_id := String(slot_states[slot_id])
        if not can_add(item_id, 1) or not add(item_id, 1):
            return false
        slot_states.erase(slot_id)
        return true

    func serialize_state() -> Dictionary:
        return {
            "max_weight": max_weight,
            "stacks": stacks.duplicate(true),
            "slot_states": slot_states.duplicate(true),
        }

    func load_state(data: Dictionary, p_defs: Dictionary = {}) -> bool:
        var active_defs: Dictionary = defs if p_defs.is_empty() else p_defs
        var candidate_stacks: Array = data.get("stacks", [])
        var candidate_slots: Dictionary = data.get("slot_states", {})
        var candidate_max_weight := float(data.get("max_weight", max_weight))
        var candidate_weight := 0.0
        for raw in candidate_stacks:
            var stack: Dictionary = raw
            var item_id := String(stack.get("item_id", ""))
            var count := int(stack.get("count", 0))
            if count <= 0 or not active_defs.has(item_id):
                return false
            candidate_weight += float(active_defs[item_id].get("weight", 0.0)) * count
        for slot_id in candidate_slots:
            if not active_defs.has(String(candidate_slots[slot_id])):
                return false
        if candidate_weight > candidate_max_weight + EPS:
            return false
        defs = active_defs
        max_weight = candidate_max_weight
        stacks = candidate_stacks.duplicate(true)
        slot_states = candidate_slots.duplicate(true)
        return true


func _init() -> void:
    var source := _read_json("res://fixtures/yard_item_export.json")
    if source.is_empty():
        _fail("Could not read YARD item export fixture", 2)
        return
    var defs: Dictionary = source.get("items", {})
    if defs.size() != 10:
        _fail("Expected 10 item definitions", 3)
        return
    var bridge_manifest := _read_json("res://generated/bridge_manifest.json")
    if int(bridge_manifest.get("source_item_count", -1)) != defs.size():
        _fail("GLoot bridge manifest item count mismatch", 4)
        return

    var lightweight := _run_lightweight(defs)
    if not bool(lightweight.get("pass", false)):
        _fail("Lightweight inventory P0 failed: %s" % lightweight.get("error", "unknown"), 5)
        return

    var gloot := _run_gloot()
    if not bool(gloot.get("pass", false)):
        _fail("GLoot inventory P0 failed: %s" % gloot.get("error", "unknown"), 6)
        return

    var report := {
        "result": "PASS",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "fixture_items": defs.size(),
        "lightweight": lightweight,
        "gloot": gloot,
        "decision_state": "AUTOMATED_COMPARISON_COMPLETE_HUMAN_EDITOR_UX_PENDING",
    }
    _write_report(report)
    print("[P0-4] SUMMARY | %s" % JSON.stringify(report))
    print("[P0-4] PASS")
    quit(0)


func _run_lightweight(defs: Dictionary) -> Dictionary:
    var inv := LightweightInventory.new(defs, 50.0)
    if not inv.add("scrap", 120):
        return {"pass": false, "error": "I1 add 120 scrap failed"}
    if _counts(inv, "scrap") != [21, 99]:
        return {"pass": false, "error": "I1 expected scrap stacks 21 + 99"}

    var idx99 := _find_count(inv, "scrap", 99)
    if idx99 < 0 or not inv.split_stack(idx99, 40):
        return {"pass": false, "error": "I2 split 99 -> 59 + 40 failed"}
    if _counts(inv, "scrap") != [21, 40, 59]:
        return {"pass": false, "error": "I2 split shape mismatch"}

    var idx59 := _find_count(inv, "scrap", 59)
    var idx40 := _find_count(inv, "scrap", 40)
    if idx59 < 0 or idx40 < 0 or not inv.merge_stacks(idx59, idx40):
        return {"pass": false, "error": "I3 merge 59 + 40 failed"}
    if _counts(inv, "scrap") != [21, 99]:
        return {"pass": false, "error": "I3 merge shape mismatch"}
    if absf(inv.current_weight() - 24.0) > EPS:
        return {"pass": false, "error": "I4 weight mismatch"}

    var limited := LightweightInventory.new(defs, 1.0)
    if limited.can_add("portable_power", 1) or limited.add("portable_power", 1):
        return {"pass": false, "error": "I5 hard limit accepted overweight item"}
    if not limited.stacks.is_empty():
        return {"pass": false, "error": "I5 hard limit partially mutated inventory"}

    var warehouse := LightweightInventory.new(defs, 100.0)
    var expedition := LightweightInventory.new(defs, 5.0)
    warehouse.add("scrap", 50)
    if not warehouse.transfer_to(expedition, "scrap", 20):
        return {"pass": false, "error": "I6 valid transfer failed"}
    var before_source := warehouse.total_count("scrap")
    var before_target := expedition.total_count("scrap")
    if warehouse.transfer_to(expedition, "scrap", 10):
        return {"pass": false, "error": "I6 overweight transfer unexpectedly succeeded"}
    if warehouse.total_count("scrap") != before_source or expedition.total_count("scrap") != before_target:
        return {"pass": false, "error": "I6 failed transfer was not atomic"}

    var keys := LightweightInventory.new(defs, 10.0)
    keys.add("key_archive_item", 1)
    if keys.discard("key_archive_item", 1):
        return {"pass": false, "error": "I7 key item was discardable"}

    var modules := LightweightInventory.new(defs, 20.0)
    modules.add("scanner", 1)
    modules.add("hack_kit", 1)
    if not modules.equip_module("slot_utility", "utility", "scanner"):
        return {"pass": false, "error": "I8 compatible module rejected"}
    if modules.equip_module("slot_utility_2", "utility", "hack_kit"):
        return {"pass": false, "error": "I8 incompatible module accepted"}
    if not modules.unequip_module("slot_utility"):
        return {"pass": false, "error": "I8 module unequip failed"}

    var many := LightweightInventory.new(defs, 1000.0)
    if not many.add("scanner", 120) or many.stacks.size() != 120:
        return {"pass": false, "error": "I9 could not create 120 non-stackable items"}
    var saved := many.serialize_state()
    var restored := LightweightInventory.new(defs, 1.0)
    if not restored.load_state(saved):
        return {"pass": false, "error": "I9 save round-trip load failed"}
    if restored.stacks != many.stacks or restored.slot_states != many.slot_states:
        return {"pass": false, "error": "I9 round-trip mismatch"}

    var missing_defs: Dictionary = defs.duplicate(true)
    missing_defs.erase("scanner")
    var migration_target := LightweightInventory.new(defs, 1000.0)
    migration_target.add("scrap", 1)
    var before_missing := migration_target.serialize_state()
    if migration_target.load_state(saved, missing_defs):
        return {"pass": false, "error": "I10 missing definition did not fail closed"}
    if migration_target.serialize_state() != before_missing:
        return {"pass": false, "error": "I10 failure mutated existing state"}

    var emergency := LightweightInventory.new(defs, 100.0)
    emergency.add("scrap", 20)
    emergency.add("data_fragment", 10)
    emergency.add("emergency_beacon", 1, true)
    emergency.add("key_archive_item", 1)
    var extraction := _emergency_extract(emergency, ["data_fragment"], 1.0)
    if not bool(extraction.get("pass", false)) or int(extraction.get("lost_count", 0)) <= 0:
        return {"pass": false, "error": "Emergency extraction contract failed"}

    return {
        "pass": true,
        "i1_i10": "PASS",
        "stack_count_roundtrip": restored.stacks.size(),
        "atomic_transfer": true,
        "missing_definition_fail_closed": true,
        "emergency_extraction": extraction,
    }


func _run_gloot() -> Dictionary:
    var protoset := load("res://generated/gloot_prototree.json") as JSON
    if protoset == null:
        return {"pass": false, "error": "Generated GLoot prototree did not import as JSON"}

    var inventory := Inventory.new()
    inventory.protoset = protoset
    var weight := WeightConstraint.new()
    weight.capacity = 100.0
    inventory.add_child(weight)
    get_root().add_child(inventory)

    var scrap = inventory.create_item("scrap")
    if scrap == null:
        return {"pass": false, "error": "GLoot create_item(scrap) returned null"}
    if String(scrap.get_property("source_item_id")) != "scrap":
        return {"pass": false, "error": "GLoot bridge lost source_item_id"}
    scrap.set_property("stack_size", 120)
    if not inventory.add_item_autosplitmerge(scrap):
        return {"pass": false, "error": "GLoot autosplit/merge rejected 120 scrap"}
    if _gloot_counts(inventory) != [21, 99]:
        return {"pass": false, "error": "GLoot expected 21 + 99 stacks"}
    if absf(weight.get_occupied_space() - 24.0) > EPS:
        return {"pass": false, "error": "GLoot WeightConstraint total mismatch"}

    var item99 = _gloot_find_stack(inventory, 99)
    if item99 == null:
        return {"pass": false, "error": "GLoot could not find 99 stack"}
    var split = inventory.split_stack(item99, 40)
    if split == null or _gloot_counts(inventory) != [21, 40, 59]:
        return {"pass": false, "error": "GLoot split stack contract failed"}

    var stack59 = _gloot_find_stack(inventory, 59)
    var stack40 = _gloot_find_stack(inventory, 40)
    if stack59 == null or stack40 == null or not inventory.merge_stacks(stack59, stack40, false):
        return {"pass": false, "error": "GLoot merge stack contract failed"}
    if _gloot_counts(inventory) != [21, 99]:
        return {"pass": false, "error": "GLoot merge result mismatch"}

    var serialized: Dictionary = inventory.serialize()
    var clone := Inventory.new()
    clone.protoset = protoset
    var clone_weight := WeightConstraint.new()
    clone_weight.capacity = 100.0
    clone.add_child(clone_weight)
    get_root().add_child(clone)
    if not clone.deserialize(serialized):
        return {"pass": false, "error": "GLoot deserialize returned false"}
    if _gloot_counts(clone) != [21, 99]:
        return {"pass": false, "error": "GLoot serialization round-trip stack mismatch"}

    var limited := Inventory.new()
    limited.protoset = protoset
    var limited_weight := WeightConstraint.new()
    limited_weight.capacity = 1.0
    limited.add_child(limited_weight)
    get_root().add_child(limited)
    var power = limited.create_item("portable_power")
    if power == null or limited.can_add_item(power):
        return {"pass": false, "error": "GLoot WeightConstraint hard-limit probe failed"}
    if limited.get_item_count() != 0:
        return {"pass": false, "error": "GLoot hard-limit probe mutated inventory"}

    return {
        "pass": true,
        "version": "v3.0.2",
        "commit": "ce88b7adc7b952b4df8ebe4836339de334d0d0cc",
        "license": "MIT",
        "source_bridge": true,
        "stack_split_merge": true,
        "weight_constraint": true,
        "serialization_roundtrip": true,
        "application_specific_rules_still_require_wrapper": [
            "key_item_policy",
            "secure_storage",
            "module_slot_tags",
            "emergency_extraction",
            "definition_migration"
        ],
    }


func _emergency_extract(inv: LightweightInventory, selected_ids: Array[String], carry_max: float) -> Dictionary:
    var carried_weight := 0.0
    var kept_count := 0
    var lost_count := 0
    var auto_protected := 0
    for stack: Dictionary in inv.stacks:
        var item_id := String(stack["item_id"])
        var count := int(stack["count"])
        var defn: Dictionary = inv.definition(item_id)
        var is_auto := bool(stack.get("secure", false)) or bool(defn.get("key_item", false))
        if is_auto:
            kept_count += count
            auto_protected += count
            continue
        var stack_weight := float(defn.get("weight", 0.0)) * count
        if selected_ids.has(item_id) and carried_weight + stack_weight <= carry_max + EPS:
            kept_count += count
            carried_weight += stack_weight
        else:
            lost_count += count
    return {
        "pass": auto_protected >= 2 and carried_weight <= carry_max + EPS,
        "kept_count": kept_count,
        "lost_count": lost_count,
        "selected_weight": carried_weight,
        "auto_protected_count": auto_protected,
    }


func _counts(inv: LightweightInventory, item_id: String) -> Array:
    var result: Array = []
    for stack: Dictionary in inv.stacks:
        if String(stack["item_id"]) == item_id:
            result.append(int(stack["count"]))
    result.sort()
    return result


func _find_count(inv: LightweightInventory, item_id: String, count: int) -> int:
    for i in range(inv.stacks.size()):
        if String(inv.stacks[i]["item_id"]) == item_id and int(inv.stacks[i]["count"]) == count:
            return i
    return -1


func _gloot_counts(inventory) -> Array:
    var result: Array = []
    for item in inventory.get_items():
        result.append(int(item.get_property("stack_size")))
    result.sort()
    return result


func _gloot_find_stack(inventory, count: int):
    for item in inventory.get_items():
        if int(item.get_property("stack_size")) == count:
            return item
    return null


func _read_json(path: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    if text.is_empty():
        return {}
    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed


func _write_report(report: Dictionary) -> void:
    var dir_path := ProjectSettings.globalize_path("res://result/runtime")
    DirAccess.make_dir_recursive_absolute(dir_path)
    var file := FileAccess.open("res://result/runtime/p0-4-inventory.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "\t") + "\n")


func _fail(message: String, code: int) -> void:
    push_error(message)
    quit(code)
