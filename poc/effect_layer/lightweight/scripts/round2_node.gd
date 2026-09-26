extends Node

const Bridge := preload("res://scripts/light_effect_bridge.gd")
const Harness := preload("res://scripts/battle_harness.gd")

func _fail(message: String, code: int) -> void:
    push_error(message)
    get_tree().quit(code)

func _ready() -> void:
    var guardian := Bridge.new(&"char_bastion")
    var ally := Bridge.new(&"char_falcon")
    var enemy := Bridge.new(&"enemy_sentry")

    guardian.register_effect(&"status_counter", {"duration_turns":2,"granted_tags":[&"Status.Counter"]})
    guardian.register_effect(&"status_intercept", {"duration_turns":2,"granted_tags":[&"Status.Intercept"]})
    guardian.register_effect(&"position_front", {"duration_turns":0,"granted_tags":[&"Position.Front"]})
    enemy.register_effect(&"status_mark", {"duration_turns":3,"granted_tags":[&"Status.Mark"]})

    guardian.apply(&"position_front", &"system")
    if absf(guardian.guard - 12.0) > 0.001:
        _fail("Position modifier failed", 20)
        return
    guardian.remove(&"position_front")
    if absf(guardian.guard - 10.0) > 0.001:
        _fail("Position modifier revert failed", 21)
        return

    guardian.apply(&"status_counter", &"char_bastion")
    guardian.apply(&"status_intercept", &"char_bastion")
    var harness := Harness.new()
    var final_target := harness.resolve_incoming_attack(&"char_falcon", ally, guardian)
    if final_target != &"char_bastion" or harness.queued_actions.size() != 1:
        _fail("Counter/Intercept failed", 22)
        return

    enemy.apply(&"status_mark", &"char_falcon")
    harness.consume_mark_for_link(enemy)
    if harness.sync != 1 or enemy.has_tag(&"Status.Mark"):
        _fail("Link failed", 23)
        return

    guardian.apply(&"status_counter", &"char_bastion")
    guardian.advance_turn()
    var dto := guardian.export_dto()
    var before := JSON.stringify(dto)
    var dump_before := guardian.debug_dump()
    guardian.restore_dto(dto)
    var after := JSON.stringify(guardian.export_dto())
    if before != after or dump_before != guardian.debug_dump():
        _fail("Save DTO round-trip failed", 24)
        return

    guardian.clear_all()
    guardian.apply(&"status_counter", &"char_bastion")
    guardian.advance_turn()
    var deterministic_a := JSON.stringify(guardian.export_dto())
    guardian.clear_all()
    guardian.apply(&"status_counter", &"char_bastion")
    guardian.advance_turn()
    var deterministic_b := JSON.stringify(guardian.export_dto())
    if deterministic_a != deterministic_b:
        _fail("Deterministic state failed", 25)
        return

    print("[P0-2:LIGHT:R2] DEBUG | " + guardian.debug_dump())
    print("[P0-2:LIGHT:R2] PASS | intercept=pass | counter=pass | link=pass | save_dto=pass | deterministic=pass | position_modifier=pass | debug=pass")
    get_tree().quit(0)
