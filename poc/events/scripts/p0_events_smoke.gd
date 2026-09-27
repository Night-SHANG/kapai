extends SceneTree

const RegistryClass := preload("res://addons/yard/registry.gd")
const EventDomainClass := preload("res://scripts/event_domain.gd")
const DialogueBridgeClass := preload("res://scripts/dialogue_bridge.gd")
const REGISTRY_PATH := "res://data/events_registry.tres"

var domain
var bridge

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var version := Engine.get_version_info()
    if int(version.get("major", -1)) != 4 or int(version.get("minor", -1)) != 7 or int(version.get("patch", -1)) != 1 or String(version.get("status", "")) != "stable":
        _fail("Wrong Godot version", 2)
        return

    if not ResourceLoader.exists(REGISTRY_PATH):
        _fail("YARD event registry missing", 3)
        return
    var registry: Variant = ResourceLoader.load(REGISTRY_PATH)
    if registry == null or registry.get_script() != RegistryClass or int(registry.size()) != 3:
        _fail("YARD event registry invalid", 4)
        return

    var sealed_resource: Variant = registry.load_entry(&"event_test_sealed_lab")
    var alarm_resource: Variant = registry.load_entry(&"event_test_lab_alarm")
    var repeat_resource: Variant = registry.load_entry(&"event_test_scavenger_ping")
    if sealed_resource == null or alarm_resource == null or repeat_resource == null:
        _fail("YARD stable ID lookup failed", 5)
        return

    var sealed: Dictionary = sealed_resource.payload
    var alarm: Dictionary = alarm_resource.payload
    var repeat_event: Dictionary = repeat_resource.payload

    domain = EventDomainClass.new()
    bridge = DialogueBridgeClass.new()

    var baseline := _base_state()
    var base_options: Array[String] = domain.get_available_options(sealed, baseline)
    if base_options != ["option_force", "option_leave"]:
        _fail("Base FTL options mismatch: %s" % base_options, 6)
        return

    var breach_state := _base_state()
    breach_state["inventory"]["item_breach_charge_test"] = 1
    if not domain.get_available_options(sealed, breach_state).has("option_breach"):
        _fail("Breach option did not appear", 7)
        return

    var engineering_state := _base_state()
    engineering_state["party"]["tags"].append("Engineering")
    if not domain.get_available_options(sealed, engineering_state).has("option_engineering"):
        _fail("Engineering option did not appear", 8)
        return

    var research_state := _base_state()
    research_state["research"]["research_old_access_protocol"] = true
    if not domain.get_available_options(sealed, research_state).has("option_research_auth"):
        _fail("Research option did not appear", 9)
        return

    var preview: Dictionary = domain.preview_option(sealed, "option_breach", breach_state)
    if not bool(preview.get("ok", false)) or Array(preview.get("changes", [])).size() != 3:
        _fail("Command-derived preview failed", 10)
        return

    var atomic_state := _base_state()
    var atomic_before := JSON.stringify(atomic_state)
    var atomic_commands := [
        {"type": "RemoveItem", "args": {"item_id": "item_breach_charge_test", "count": 1}},
        {"type": "ChangeThreat", "args": {"amount": 8}},
        {"type": "SetLocationState", "args": {"location_id": "location_test_sealed_lab", "key": "lab_opened", "value": true}},
    ]
    var atomic_result: Dictionary = domain.resolve_commands_transactional(atomic_commands, atomic_state)
    if bool(atomic_result.get("ok", false)) or JSON.stringify(atomic_state) != atomic_before:
        _fail("Atomic failure mutated state", 11)
        return

    var resolve_state := _base_state()
    resolve_state["party"]["tags"].append("Engineering")
    var resolved: Dictionary = domain.resolve_option(sealed, "option_engineering", resolve_state)
    if not bool(resolved.get("ok", false)):
        _fail("Engineering resolve failed", 12)
        return
    if int(resolve_state["expedition"]["threat"]) != 12:
        _fail("Engineering threat result mismatch", 13)
        return
    if not bool(resolve_state["locations"]["location_test_sealed_lab"]["local_flags"]["lab_opened"]):
        _fail("Engineering did not open laboratory", 14)
        return
    if int(resolve_state["resources"]["data"]) != 1:
        _fail("Engineering reward mismatch", 15)
        return
    if domain.is_event_available(sealed, resolve_state):
        _fail("Once event remained available after completion", 16)
        return

    var save_text := JSON.stringify(resolve_state)
    var restored: Variant = JSON.parse_string(save_text)
    if not restored is Dictionary:
        _fail("EventHistory JSON round-trip did not restore a Dictionary", 17)
        return
    var restored_state: Dictionary = restored
    var original_history: Dictionary = resolve_state.get("event_history", {})
    var restored_history: Dictionary = restored_state.get("event_history", {})
    var original_entry: Dictionary = original_history.get("event_test_sealed_lab", {})
    var restored_entry: Dictionary = restored_history.get("event_test_sealed_lab", {})
    if int(restored_entry.get("times", -1)) != int(original_entry.get("times", -1))     or int(restored_entry.get("last_cycle", -1)) != int(original_entry.get("last_cycle", -1)):
        _fail("EventHistory JSON round-trip changed persisted semantics", 17)
        return
    if domain.is_event_available(sealed, restored_state):
        _fail("Restored EventHistory no longer enforces once semantics", 17)
        return

    if not domain.is_event_available(alarm, resolve_state):
        _fail("Event chain did not unlock alarm after lab open", 18)
        return
    var battle_start: Dictionary = domain.resolve_option(alarm, "option_engage", resolve_state)
    if not bool(battle_start.get("ok", false)) or not bool(battle_start.get("awaiting_battle", false)):
        _fail("StartBattle bridge failed", 19)
        return
    var pending: Dictionary = resolve_state["expedition"]["pending_battle"]
    if String(pending.get("encounter_id", "")) != "encounter_test_lab_guard":
        _fail("Pending battle encounter mismatch", 20)
        return
    var continuation: Dictionary = domain.continue_after_battle(alarm, "option_engage", "win", resolve_state)
    if not bool(continuation.get("ok", false)):
        _fail("Battle continuation failed", 21)
        return
    if not bool(resolve_state["world_flags"]["lab_guard_defeated"]) or int(resolve_state["resources"]["data"]) != 3:
        _fail("Battle win continuation results mismatch", 22)
        return

    var repeat_state := _base_state()
    if not bool(domain.resolve_option(repeat_event, "option_collect", repeat_state).get("ok", false)):
        _fail("Cooldown event initial resolve failed", 23)
        return
    repeat_state["world_cycle"] = 2
    if domain.is_event_available(repeat_event, repeat_state):
        _fail("Cooldown event returned too early", 24)
        return
    repeat_state["world_cycle"] = 3
    if not domain.is_event_available(repeat_event, repeat_state):
        _fail("Cooldown event did not return after cooldown", 25)
        return

    var presentation_state := _base_state()
    var presentation_hash_before := JSON.stringify(presentation_state)
    var intro: Dictionary = await bridge.resolve_intro(sealed)
    if not bool(intro.get("ok", false)) or String(intro.get("text", "")).is_empty():
        _fail("Dialogue Manager intro bridge failed", 26)
        return
    var labels_result: Dictionary = await bridge.resolve_option_labels(sealed, base_options)
    if not bool(labels_result.get("ok", false)):
        _fail("Dialogue Manager option-label bridge failed", 27)
        return
    var labels: Dictionary = labels_result.get("labels", {})
    if labels.size() != 2 or String(labels.get("option_force", "")).is_empty() or String(labels.get("option_leave", "")).is_empty():
        _fail("Dialogue Manager returned incomplete option labels", 28)
        return
    var selection: Dictionary = bridge.select_option("option_force", base_options)
    if not bool(selection.get("ok", false)) or String(selection.get("option_id", "")) != "option_force":
        _fail("Dialogue bridge did not return option_id", 29)
        return
    if JSON.stringify(presentation_state) != presentation_hash_before:
        _fail("Presentation bridge mutated WorldState", 30)
        return

    var condition_probe := _condition_probe(_base_state())
    if not bool(condition_probe.get("pass", false)):
        _fail("Condition base-set probe failed: %s" % condition_probe.get("failed", ""), 31)
        return

    var report := {
        "result": "PASS",
        "engine": Engine.get_version_info().get("string", "unknown"),
        "yard_registry_entries": registry.size(),
        "event_count": 3,
        "sealed_lab_base_options": base_options,
        "ftl_special_options": true,
        "condition_base_set": "PASS",
        "command_atomicity": true,
        "preview_from_command_data": true,
        "once_history": true,
        "cooldown_history": true,
        "save_boundary_json_roundtrip": true,
        "event_chain_reachability_runtime": true,
        "battle_continuation": true,
        "dialogue_manager": {
            "version": "v4.1.0",
            "commit": "a719088aea342572f29b5559fd8726896c9519b2",
            "presentation_only": true,
            "option_id_return": true,
            "state_unchanged": true,
        },
        "yard": {
            "version": "v1.2.0",
            "commit": "48a518b4bec03c8b5ad446f57a2b669110a1752b",
            "event_definition_authority": true,
        },
        "gdunit4": {
            "version": "v6.2.1",
            "commit": "08ffc7c65b61b1b2edd545616061a99973c13ce1",
        },
        "save_boundary": "Only committed domain state is persisted; unselected UI state is presentation-only.",
    }
    _write_report(report)
    print("[P0-5] SUMMARY | %s" % JSON.stringify(report))
    print("[P0-5] PASS")
    quit(0)

func _condition_probe(state: Dictionary) -> Dictionary:
    state["inventory"]["item_breach_charge_test"] = 2
    state["party"]["tags"].append("Engineering")
    state["research"]["research_old_access_protocol"] = true
    state["resources"]["data"] = 3
    state["world_flags"]["lab_guard_defeated"] = true
    state["event_history"]["event_seen_probe"] = {"times": 1, "last_cycle": 1}

    var probes := {
        "HasCharacter": {"type": "HasCharacter", "args": {"character_id": "char_loom"}},
        "PartyHasTag": {"type": "PartyHasTag", "args": {"tag": "Engineering"}},
        "HasItem": {"type": "HasItem", "args": {"item_id": "item_breach_charge_test"}},
        "ItemCountAtLeast": {"type": "ItemCountAtLeast", "args": {"item_id": "item_breach_charge_test", "count": 2}},
        "HasResearch": {"type": "HasResearch", "args": {"research_id": "research_old_access_protocol"}},
        "ResourceAtLeast": {"type": "ResourceAtLeast", "args": {"resource_id": "data", "amount": 3}},
        "ThreatRange": {"type": "ThreatRange", "args": {"min": 5, "max": 15}},
        "LocationState": {"type": "LocationState", "args": {"location_id": "location_test_sealed_lab", "key": "lab_opened", "value": false}},
        "WorldFlag": {"type": "WorldFlag", "args": {"flag": "lab_guard_defeated", "value": true}},
        "EventSeen": {"type": "EventSeen", "args": {"event_id": "event_seen_probe"}},
        "EventNotSeen": {"type": "EventNotSeen", "args": {"event_id": "event_not_seen_probe"}},
        "ALL": {"type": "ALL", "args": {"conditions": [
            {"type": "HasCharacter", "args": {"character_id": "char_loom"}},
            {"type": "PartyHasTag", "args": {"tag": "Engineering"}}
        ]}},
        "ANY": {"type": "ANY", "args": {"conditions": [
            {"type": "HasResearch", "args": {"research_id": "missing"}},
            {"type": "HasResearch", "args": {"research_id": "research_old_access_protocol"}}
        ]}},
        "NOT": {"type": "NOT", "args": {"condition": {"type": "WorldFlag", "args": {"flag": "expedition_wiped", "value": true}}}},
    }
    for key: String in probes:
        if not domain.condition_matches(probes[key], state):
            return {"pass": false, "failed": key}
    return {"pass": true, "failed": ""}

func _base_state() -> Dictionary:
    return {
        "world_cycle": 1,
        "world_flags": {"lab_guard_defeated": false, "expedition_wiped": false},
        "resources": {"scrap": 0, "data": 0, "core": 0},
        "research": {"research_old_access_protocol": false},
        "event_history": {},
        "locations": {
            "location_test_sealed_lab": {
                "state": "sealed",
                "local_flags": {"lab_opened": false},
            }
        },
        "discovered_locations": ["location_test_sealed_lab"],
        "unlocked_routes": [],
        "restored_facilities": [],
        "archives": [],
        "party": {
            "character_ids": ["char_bastion", "char_falcon", "char_loom"],
            "tags": ["Heavy", "Recon"],
        },
        "inventory": {},
        "expedition": {
            "threat": 10,
            "current_hp_by_character": {
                "char_bastion": 20,
                "char_falcon": 16,
                "char_loom": 16,
            },
            "injuries": {},
            "pending_battle": {},
        },
    }

func _write_report(report: Dictionary) -> void:
    var dir_path := ProjectSettings.globalize_path("res://result/runtime")
    DirAccess.make_dir_recursive_absolute(dir_path)
    var file := FileAccess.open("res://result/runtime/p0-5-events.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(report, "\t") + "\n")

func _fail(message: String, code: int) -> void:
    push_error(message)
    quit(code)
