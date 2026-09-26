extends Node

func _fail(message: String, code: int) -> void:
    push_error(message)
    get_tree().quit(code)

func _stage(name: String) -> void:
    print("[P0-2:GAS] STAGE | " + name)

func _ready() -> void:
    _stage("start")

    var version := Engine.get_version_info()
    if int(version.get("major", -1)) != 4 or int(version.get("minor", -1)) != 7 or int(version.get("patch", -1)) != 1 or String(version.get("status", "")) != "stable":
        _fail("P0-2 requires Godot 4.7.1 stable", 2)
        return

    _stage("create_actor")
    var actor := Node.new()
    actor.name = "P0Actor"
    add_child(actor)

    var asc := AbilitySystemComponent.new()
    asc.name = "AbilitySystemComponent"
    actor.add_child(asc)

    _stage("query_without_mark")
    var exposed_query := GameplayTagQuery.new()
    exposed_query.require_all_tags = [&"Status.Mark"]

    var exposed := GameplayEffect.new()
    exposed.policy = GameplayEffect.DurationPolicy.TURN_BASED
    exposed.duration_turns = 2
    exposed.granted_tags = [&"Status.Exposed"]
    exposed.application_query = exposed_query

    var rejected = asc.apply_gameplay_effect(exposed, asc)
    if rejected != null:
        _fail("Exposed should be rejected without Mark", 3)
        return

    _stage("apply_mark")
    var mark := GameplayEffect.new()
    mark.policy = GameplayEffect.DurationPolicy.TURN_BASED
    mark.duration_turns = 2
    mark.granted_tags = [&"Status.Mark"]

    var mark_active = asc.apply_gameplay_effect(mark, asc)
    if mark_active == null or not asc.has_tag(&"Status.Mark"):
        _fail("Mark application failed", 4)
        return

    _stage("query_with_mark")
    var exposed_active = asc.apply_gameplay_effect(exposed, asc)
    if exposed_active == null or not asc.has_tag(&"Status.Exposed"):
        _fail("GameplayTagQuery did not allow Exposed after Mark", 5)
        return

    _stage("build_stack_effects")
    var stagger := GameplayEffect.new()
    stagger.policy = GameplayEffect.DurationPolicy.TURN_BASED
    stagger.duration_turns = 1
    stagger.granted_tags = [&"Status.Stagger"]

    var break_effect := GameplayEffect.new()
    break_effect.policy = GameplayEffect.DurationPolicy.TURN_BASED
    break_effect.duration_turns = 3
    break_effect.stacking_policy = GameplayEffect.StackingPolicy.REFRESH_DURATION
    break_effect.max_stacks = 3
    break_effect.granted_tags = [&"Status.Break"]
    break_effect.overflow_effects = [stagger]

    _stage("stack_1")
    var break_active = asc.apply_gameplay_effect(break_effect, asc)
    if break_active == null or break_active.stack_count != 1:
        _fail("Break stack 1 failed", 6)
        return

    _stage("stack_2")
    break_active = asc.apply_gameplay_effect(break_effect, asc)
    if break_active == null or break_active.stack_count != 2:
        _fail("Break stack 2 failed", 7)
        return

    _stage("stack_3")
    break_active = asc.apply_gameplay_effect(break_effect, asc)
    if break_active == null or break_active.stack_count != 3:
        _fail("Break stack 3 failed", 8)
        return

    _stage("overflow")
    asc.apply_gameplay_effect(break_effect, asc)
    if not asc.has_tag(&"Status.Stagger"):
        _fail("Break overflow did not apply Stagger", 9)
        return
    if break_active.stack_count != 3:
        _fail("Break exceeded max stack", 10)
        return

    _stage("cleanse")
    var cleanse := GameplayEffect.new()
    cleanse.policy = GameplayEffect.DurationPolicy.INSTANT
    cleanse.remove_effects_with_tags = [&"Status.Break"]
    asc.apply_gameplay_effect(cleanse, asc)

    if asc.has_tag(&"Status.Break"):
        _fail("Cleanser failed to remove Break", 11)
        return

    _stage("turn_based_delta_guard")
    asc._process(60.0)
    if not asc.has_tag(&"Status.Mark"):
        _fail("TURN_BASED Mark expired from delta processing", 12)
        return

    _stage("advance_turn_1")
    asc.advance_turn()
    if not asc.has_tag(&"Status.Mark"):
        _fail("Mark expired one turn too early", 13)
        return

    _stage("advance_turn_2")
    asc.advance_turn()
    if asc.has_tag(&"Status.Mark"):
        _fail("Mark did not expire after two advance_turn calls", 14)
        return

    _stage("cleanup")
    asc.cleanup()
    actor.queue_free()

    print("[P0-2:GAS] CORE PASS | query=pass | stack=3 | overflow=pass | cleanse=pass | turn_based=pass")
    get_tree().quit(0)
