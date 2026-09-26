extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _fail(message: String, code: int) -> void:
    push_error(message)
    quit(code)

func _run() -> void:
    var version := Engine.get_version_info()
    if int(version.get("major", -1)) != 4 or int(version.get("minor", -1)) != 7 or int(version.get("patch", -1)) != 1 or String(version.get("status", "")) != "stable":
        _fail("P0-2 requires Godot 4.7.1 stable", 2)
        return

    var actor := Node.new()
    actor.name = "P0Actor"
    root.add_child(actor)

    var asc := AbilitySystemComponent.new()
    asc.name = "AbilitySystemComponent"
    actor.add_child(asc)
    await process_frame

    # 1) Query gate: Exposed requires Mark.
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

    var mark := GameplayEffect.new()
    mark.policy = GameplayEffect.DurationPolicy.TURN_BASED
    mark.duration_turns = 2
    mark.granted_tags = [&"Status.Mark"]

    var mark_active = asc.apply_gameplay_effect(mark, asc)
    if mark_active == null or not asc.has_tag(&"Status.Mark"):
        _fail("Mark application failed", 4)
        return

    var exposed_active = asc.apply_gameplay_effect(exposed, asc)
    if exposed_active == null or not asc.has_tag(&"Status.Exposed"):
        _fail("GameplayTagQuery did not allow Exposed after Mark", 5)
        return

    # 2) Break: 3-stack cap + overflow.
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

    var break_active = asc.apply_gameplay_effect(break_effect, asc)
    if break_active == null or break_active.stack_count != 1:
        _fail("Break stack 1 failed", 6)
        return

    break_active = asc.apply_gameplay_effect(break_effect, asc)
    if break_active == null or break_active.stack_count != 2:
        _fail("Break stack 2 failed", 7)
        return

    break_active = asc.apply_gameplay_effect(break_effect, asc)
    if break_active == null or break_active.stack_count != 3:
        _fail("Break stack 3 failed", 8)
        return

    var overflow_result = asc.apply_gameplay_effect(break_effect, asc)
    if not asc.has_tag(&"Status.Stagger"):
        _fail("Break overflow did not apply Stagger", 9)
        return
    if break_active.stack_count != 3:
        _fail("Break exceeded max stack", 10)
        return

    # 3) Declarative cleanser removes Break.
    var cleanse := GameplayEffect.new()
    cleanse.policy = GameplayEffect.DurationPolicy.INSTANT
    cleanse.remove_effects_with_tags = [&"Status.Break"]
    asc.apply_gameplay_effect(cleanse, asc)

    if asc.has_tag(&"Status.Break"):
        _fail("Cleanser failed to remove Break", 11)
        return

    # 4) TURN_BASED must be driven only by advance_turn().
    # Mark has 2 turns and no delta-based expiration.
    await create_timer(0.05).timeout
    if not asc.has_tag(&"Status.Mark"):
        _fail("TURN_BASED Mark expired from real time", 12)
        return

    asc.advance_turn()
    if not asc.has_tag(&"Status.Mark"):
        _fail("Mark expired one turn too early", 13)
        return

    asc.advance_turn()
    if asc.has_tag(&"Status.Mark"):
        _fail("Mark did not expire after two advance_turn calls", 14)
        return

    print("[P0-2:GAS] CORE PASS | query=pass | stack=3 | overflow=pass | cleanse=pass | turn_based=pass")
    asc.cleanup()
    actor.queue_free()
    quit(0)
