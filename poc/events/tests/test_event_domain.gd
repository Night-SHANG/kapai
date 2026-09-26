extends GdUnitTestSuite

const EventDomainClass := preload("res://scripts/event_domain.gd")

var domain
var events: Dictionary = {}

func before() -> void:
    domain = EventDomainClass.new()
    var rows: Array = _read_json_array("res://fixtures/events.json")
    for raw: Variant in rows:
        var event_def: Dictionary = raw
        events[String(event_def["id"])] = event_def

func test_ftl_special_options() -> void:
    var event_def: Dictionary = events["event_test_sealed_lab"]
    var state := _base_state()
    assert_array(domain.get_available_options(event_def, state)).is_equal(["option_force", "option_leave"])

    state["inventory"]["item_breach_charge_test"] = 1
    assert_bool(domain.get_available_options(event_def, state).has("option_breach")).is_true()

    state["party"]["tags"].append("Engineering")
    assert_bool(domain.get_available_options(event_def, state).has("option_engineering")).is_true()

    state["research"]["research_old_access_protocol"] = true
    assert_bool(domain.get_available_options(event_def, state).has("option_research_auth")).is_true()

func test_condition_composition() -> void:
    var state := _base_state()
    state["resources"]["data"] = 3
    var probe := {
        "type": "ALL",
        "args": {"conditions": [
            {"type": "ResourceAtLeast", "args": {"resource_id": "data", "amount": 2}},
            {"type": "ANY", "args": {"conditions": [
                {"type": "PartyHasTag", "args": {"tag": "Engineering"}},
                {"type": "NOT", "args": {"condition": {"type": "WorldFlag", "args": {"flag": "lab_guard_defeated", "value": true}}}}
            ]}}
        ]}
    }
    assert_bool(domain.condition_matches(probe, state)).is_true()

func test_atomic_command_failure_does_not_mutate() -> void:
    var state := _base_state()
    var before := state.duplicate(true)
    var commands := [
        {"type": "RemoveItem", "args": {"item_id": "item_breach_charge_test", "count": 1}},
        {"type": "ChangeThreat", "args": {"amount": 8}},
        {"type": "SetLocationState", "args": {"location_id": "location_test_sealed_lab", "key": "lab_opened", "value": true}},
    ]
    var result: Dictionary = domain.resolve_commands_transactional(commands, state)
    assert_bool(bool(result["ok"])).is_false()
    assert_dict(state).is_equal(before)

func test_once_and_cooldown_history() -> void:
    var sealed: Dictionary = events["event_test_sealed_lab"]
    var state := _base_state()
    var result: Dictionary = domain.resolve_option(sealed, "option_force", state)
    assert_bool(bool(result["ok"])).is_true()
    assert_bool(domain.is_event_available(sealed, state)).is_false()

    var repeat_event: Dictionary = events["event_test_scavenger_ping"]
    var repeat_state := _base_state()
    assert_bool(bool(domain.resolve_option(repeat_event, "option_collect", repeat_state)["ok"])).is_true()
    repeat_state["world_cycle"] = 2
    assert_bool(domain.is_event_available(repeat_event, repeat_state)).is_false()
    repeat_state["world_cycle"] = 3
    assert_bool(domain.is_event_available(repeat_event, repeat_state)).is_true()

func test_preview_uses_same_command_data() -> void:
    var event_def: Dictionary = events["event_test_sealed_lab"]
    var state := _base_state()
    state["inventory"]["item_breach_charge_test"] = 1
    var preview: Dictionary = domain.preview_option(event_def, "option_breach", state)
    assert_bool(bool(preview["ok"])).is_true()
    var option: Dictionary = _find_option(event_def, "option_breach")
    assert_array(preview["changes"]).is_equal(option["commands"])

func test_battle_continuation() -> void:
    var sealed: Dictionary = events["event_test_sealed_lab"]
    var alarm: Dictionary = events["event_test_lab_alarm"]
    var state := _base_state()
    assert_bool(bool(domain.resolve_option(sealed, "option_force", state)["ok"])).is_true()
    assert_bool(domain.is_event_available(alarm, state)).is_true()

    var start: Dictionary = domain.resolve_option(alarm, "option_engage", state)
    assert_bool(bool(start["ok"])).is_true()
    assert_bool(bool(start["awaiting_battle"])).is_true()

    var resumed: Dictionary = domain.continue_after_battle(alarm, "option_engage", "win", state)
    assert_bool(bool(resumed["ok"])).is_true()
    assert_int(int(state["resources"]["data"])).is_equal(2)
    assert_bool(bool(state["world_flags"]["lab_guard_defeated"])).is_true()

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

func _find_option(event_def: Dictionary, option_id: String) -> Dictionary:
    for raw: Variant in event_def["options"]:
        var option: Dictionary = raw
        if String(option["option_id"]) == option_id:
            return option
    return {}

func _read_json_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if parsed is Array else []
