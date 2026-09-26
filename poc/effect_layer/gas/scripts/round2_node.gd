extends Node

const Bridge := preload("res://scripts/effect_bridge.gd")
const Harness := preload("res://scripts/battle_harness.gd")
const CombatAttributes := preload("res://scripts/p0_attribute_set.gd")

func _fail(message: String, code: int) -> void:
    push_error(message)
    get_tree().quit(code)

func _effect(tag: StringName, turns: int = 0) -> GameplayEffect:
    var e := GameplayEffect.new()
    e.policy = GameplayEffect.DurationPolicy.TURN_BASED if turns > 0 else GameplayEffect.DurationPolicy.INFINITE
    e.duration_turns = turns
    e.granted_tags = [tag]
    return e

func _ready() -> void:
    print("[P0-2:GAS:R2] STAGE | setup")

    var guardian_node := Node.new()
    guardian_node.name = "char_bastion"
    add_child(guardian_node)
    var guardian_asc := AbilitySystemComponent.new()
    guardian_asc.name = "AbilitySystemComponent"
    guardian_asc.attribute_sets = [CombatAttributes.new()]
    guardian_node.add_child(guardian_asc)

    var ally_node := Node.new()
    ally_node.name = "char_falcon"
    add_child(ally_node)
    var ally_asc := AbilitySystemComponent.new()
    ally_asc.name = "AbilitySystemComponent"
    ally_node.add_child(ally_asc)

    var enemy_node := Node.new()
    enemy_node.name = "enemy_sentry"
    add_child(enemy_node)
    var enemy_asc := AbilitySystemComponent.new()
    enemy_asc.name = "AbilitySystemComponent"
    enemy_node.add_child(enemy_asc)

    var guardian := Bridge.new(&"char_bastion", guardian_asc)
    var ally := Bridge.new(&"char_falcon", ally_asc)
    var enemy := Bridge.new(&"enemy_sentry", enemy_asc)

    var counter := _effect(&"Status.Counter", 2)
    var intercept := _effect(&"Status.Intercept", 2)
    var mark := _effect(&"Status.Mark", 3)

    var position := GameplayEffect.new()
    position.policy = GameplayEffect.DurationPolicy.INFINITE
    position.granted_tags = [&"Position.Front"]
    var position_mod := GameplayEffectModifier.new()
    position_mod.attribute_name = "guard"
    position_mod.operation = GameplayEffectModifier.Operation.ADD
    position_mod.magnitude = 2.0
    position.modifiers = [position_mod]

    guardian.register_effect(&"status_counter", counter)
    guardian.register_effect(&"status_intercept", intercept)
    guardian.register_effect(&"position_front", position)
    enemy.register_effect(&"status_mark", mark)

    print("[P0-2:GAS:R2] STAGE | position_modifier")
    if absf(guardian_asc.get_attribute("guard").current_value - 10.0) > 0.001:
        _fail("Base guard mismatch", 20)
        return
    guardian.apply(&"position_front", &"system")
    if absf(guardian_asc.get_attribute("guard").current_value - 12.0) > 0.001:
        _fail("Position modifier did not add +2 guard", 21)
        return
    guardian.remove(&"position_front")
    if absf(guardian_asc.get_attribute("guard").current_value - 10.0) > 0.001:
        _fail("Position modifier did not revert cleanly", 22)
        return

    print("[P0-2:GAS:R2] STAGE | counter_intercept")
    guardian.apply(&"status_counter", &"char_bastion")
    guardian.apply(&"status_intercept", &"char_bastion")

    var harness := Harness.new()
    var final_target := harness.resolve_incoming_attack(&"char_falcon", ally, guardian)
    if final_target != &"char_bastion":
        _fail("Intercept did not rewrite target", 23)
        return
    if guardian.has_tag(&"Status.Intercept"):
        _fail("Intercept was not consumed", 24)
        return
    if guardian.has_tag(&"Status.Counter"):
        _fail("Counter was not consumed", 25)
        return
    if harness.queued_actions.size() != 1 or harness.queued_actions[0]["type"] != "counter":
        _fail("Counter action was not queued by Battle Harness", 26)
        return

    print("[P0-2:GAS:R2] STAGE | link")
    enemy.apply(&"status_mark", &"char_falcon")
    harness.consume_mark_for_link(enemy)
    if harness.sync != 1 or enemy.has_tag(&"Status.Mark"):
        _fail("Link/Mark consumption failed", 27)
        return

    print("[P0-2:GAS:R2] STAGE | save_dto")
    guardian.apply(&"status_counter", &"char_bastion")
    guardian.advance_turn()

    var dto := guardian.export_dto()
    var before := JSON.stringify(dto)
    var dump_before := guardian.debug_dump()
    if dto.size() != 1:
        _fail("Unexpected GAS DTO entry count: %d" % dto.size(), 28)
        return

    guardian.clear_all()
    if guardian.has_tag(&"Status.Counter"):
        _fail("clear_all failed before restore", 29)
        return

    guardian.restore_dto(dto)
    var after := JSON.stringify(guardian.export_dto())
    var dump_after := guardian.debug_dump()
    if before != after:
        _fail("Save DTO round-trip mismatch\nBEFORE=%s\nAFTER=%s" % [before, after], 30)
        return
    if dump_before != dump_after:
        _fail("Debug dump changed after restore", 31)
        return

    print("[P0-2:GAS:R2] STAGE | deterministic")
    guardian.clear_all()
    guardian.apply(&"status_counter", &"char_bastion")
    guardian.advance_turn()
    var deterministic_a := JSON.stringify(guardian.export_dto())

    guardian.clear_all()
    guardian.apply(&"status_counter", &"char_bastion")
    guardian.advance_turn()
    var deterministic_b := JSON.stringify(guardian.export_dto())

    if deterministic_a != deterministic_b:
        _fail("Deterministic effect state mismatch for identical commands", 32)
        return

    print("[P0-2:GAS:R2] DEBUG | " + guardian.debug_dump())
    print("[P0-2:GAS:R2] PASS | intercept=pass | counter=pass | link=pass | save_dto=pass | deterministic=pass | position_modifier=pass | debug=pass")

    guardian.clear_all()
    enemy.clear_all()
    guardian_asc.cleanup()
    ally_asc.cleanup()
    enemy_asc.cleanup()
    get_tree().quit(0)
