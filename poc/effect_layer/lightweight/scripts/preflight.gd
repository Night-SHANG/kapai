extends SceneTree

const Runtime := preload("res://scripts/effect_runtime.gd")

func _fail(message: String, code: int) -> void:
    push_error(message)
    quit(code)

func _init() -> void:
    var version := Engine.get_version_info()
    if int(version.get("major", -1)) != 4 or int(version.get("minor", -1)) != 7 or int(version.get("patch", -1)) != 1 or String(version.get("status", "")) != "stable":
        _fail("P0-2 requires Godot 4.7.1 stable", 2)
        return

    var runtime = Runtime.new()

    var exposed := {
        "id": &"status_exposed",
        "duration_turns": 2,
        "granted_tags": [&"Status.Exposed"],
        "require_all_tags": [&"Status.Mark"],
    }

    if not runtime.apply(exposed).is_empty():
        _fail("Exposed should be rejected without Mark", 3)
        return

    var mark := {
        "id": &"status_mark",
        "duration_turns": 2,
        "granted_tags": [&"Status.Mark"],
    }
    runtime.apply(mark)

    if runtime.apply(exposed).is_empty() or not runtime.has_tag(&"Status.Exposed"):
        _fail("Query did not allow Exposed after Mark", 4)
        return

    var break_def := {
        "id": &"status_break",
        "duration_turns": 3,
        "granted_tags": [&"Status.Break"],
        "max_stacks": 3,
        "overflow_tag": &"Status.Stagger",
    }

    var state = runtime.apply(break_def)
    state = runtime.apply(break_def)
    state = runtime.apply(break_def)
    if int(state["stacks"]) != 3:
        _fail("Break did not reach 3 stacks", 5)
        return

    state = runtime.apply(break_def)
    if int(state["stacks"]) != 3 or not runtime.has_tag(&"Status.Stagger"):
        _fail("Break overflow failed", 6)
        return

    runtime.apply({
        "id": &"action_cleanse_break",
        "duration_turns": 0,
        "remove_effects_with_tags": [&"Status.Break"],
    })

    if runtime.has_tag(&"Status.Break"):
        _fail("Cleanse failed", 7)
        return

    runtime.advance_turn()
    if not runtime.has_tag(&"Status.Mark"):
        _fail("Mark expired one turn too early", 8)
        return

    runtime.advance_turn()
    if runtime.has_tag(&"Status.Mark"):
        _fail("Mark did not expire after two turns", 9)
        return

    print("[P0-2:LIGHT] CORE PASS | query=pass | stack=3 | overflow=pass | cleanse=pass | turn_based=pass")
    quit(0)
