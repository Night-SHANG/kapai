extends GdUnitTestSuite

func test_real_schema_fixture_contract() -> void:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/schema_v3.json"))
    assert_bool(data is Dictionary).is_true()
    var state: Dictionary = data
    assert_int(int(state.get("schema_version", -1))).is_equal(3)
    assert_int(int(state.get("expedition", {}).get("threat", -1))).is_equal(58)
    assert_int(int(state.get("battle", {}).get("turn", -1))).is_equal(7)
    assert_int(Array(state.get("characters", [])).size()).is_equal(8)
    assert_int(Array(state.get("inventory", {}).get("stacks", [])).size()).is_equal(10)
    assert_int(Dictionary(state.get("rng_streams", {})).size()).is_equal(5)

func test_battle_rng_resume_contract() -> void:
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fixtures/schema_v3.json"))
    var a: Dictionary = data.duplicate(true)
    var b: Dictionary = data.duplicate(true)
    _next_command(a)
    _next_command(b)
    assert_int(int(a["rng_streams"]["battle_draw"]["state"])).is_equal(int(b["rng_streams"]["battle_draw"]["state"]))
    assert_int(int(a["battle"]["enemy_hp"]["enemy_guard_a"])).is_equal(int(b["battle"]["enemy_hp"]["enemy_guard_a"]))

func _next_command(state: Dictionary) -> void:
    var old_state: int = int(state["rng_streams"]["battle_draw"]["state"])
    var next_state: int = int((old_state * 1103515245 + 12345) & 0x7fffffff)
    state["rng_streams"]["battle_draw"]["state"] = next_state
    var damage: int = 1 + (next_state % 5)
    state["battle"]["enemy_hp"]["enemy_guard_a"] = int(state["battle"]["enemy_hp"]["enemy_guard_a"]) - damage
