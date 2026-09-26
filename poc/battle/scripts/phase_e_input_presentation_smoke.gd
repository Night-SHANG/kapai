extends SceneTree

const HAND_IDS: Array[String] = [
    "card_bastion_guard_stance",
    "card_bastion_intercept",
    "card_falcon_mark",
    "card_falcon_precision_shot",
    "card_loom_tactical_link",
    "card_loom_repair",
]

func _init() -> void:
    _run.call_deferred()

func _run() -> void:
    var battle_state := {
        "turn": 1,
        "plays_remaining": 3,
        "redraws_remaining": 2,
        "sync": 0,
        "formation": ["char_bastion", "char_loom", "char_falcon"],
        "hand_ids": HAND_IDS.duplicate(),
        "enemy_intent": {
            "id": "intent_attack_light",
            "type": "attack",
            "target": "char_bastion",
            "damage": 3,
        },
    }

    var state_before := JSON.stringify(battle_state)

    var scene := Control.new()
    scene.name = "P0PhaseEScene"
    root.add_child(scene)
    current_scene = scene

    var manager_scene := load("res://addons/card-framework/card_manager.tscn") as PackedScene
    if manager_scene == null:
        _fail("Card Framework CardManager scene failed to load", 2)
        return

    var manager := manager_scene.instantiate()
    scene.add_child(manager)

    var hand := P0PresentationHand.new()
    hand.name = "PresentationHand"
    hand.position = Vector2(640, 500)
    hand.max_hand_spread = 720
    scene.add_child(hand)

    await process_frame

    if hand.card_manager == null:
        _fail("Presentation Hand did not discover CardManager", 3)
        return

    var presenter := CardFrameworkPresenter.new()
    var presentation := presenter.render_hand(hand, HAND_IDS)
    await process_frame

    if not bool(presentation.get("ok", false)):
        _fail("Presenter failed: %s" % JSON.stringify(presentation), 4)
        return
    if int(presentation.get("count", 0)) != 6:
        _fail("Expected six rendered cards", 5)
        return
    if not bool(presentation.get("framework_interaction_disabled", false)):
        _fail("Card Framework drag interaction must be disabled in presentation-only adapter", 6)
        return

    var state_after := JSON.stringify(battle_state)
    if state_after != state_before:
        _fail("Presentation mutated BattleState", 7)
        return

    var router := BattleInputRouter.new()
    router.configure(HAND_IDS)

    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.pressed = true
    var mouse_command := router.handle_event(mouse, HAND_IDS[2])

    router.reset_selection()
    for _i in range(2):
        var right := InputEventKey.new()
        right.keycode = KEY_RIGHT
        right.pressed = true
        router.handle_event(right)
    var enter := InputEventKey.new()
    enter.keycode = KEY_ENTER
    enter.pressed = true
    var keyboard_command := router.handle_event(enter)

    router.reset_selection()
    for _i in range(2):
        var dpad := InputEventJoypadButton.new()
        dpad.button_index = JOY_BUTTON_DPAD_RIGHT
        dpad.pressed = true
        router.handle_event(dpad)
    var confirm := InputEventJoypadButton.new()
    confirm.button_index = JOY_BUTTON_A
    confirm.pressed = true
    var gamepad_command := router.handle_event(confirm)

    if mouse_command.is_empty() or keyboard_command.is_empty() or gamepad_command.is_empty():
        _fail("One or more input paths did not emit a BattleCommand", 8)
        return
    if JSON.stringify(mouse_command) != JSON.stringify(keyboard_command):
        _fail("Mouse and keyboard commands diverged", 9)
        return
    if JSON.stringify(mouse_command) != JSON.stringify(gamepad_command):
        _fail("Mouse and gamepad commands diverged", 10)
        return
    if String(mouse_command.get("card_id", "")) != HAND_IDS[2]:
        _fail("Unified input path selected wrong card", 11)
        return
    if router.command_log.size() != 3:
        _fail("Expected exactly three routed commands", 12)
        return

    var summary := {
        "framework": {
            "name": "chun92/card-framework",
            "version": "v1.4.0",
            "commit": "a74b713863adb27a22965a8e6ed039d0c4016791",
            "license": "MIT",
            "role": "presentation_only",
            "rendered_cards": presentation["count"],
            "framework_drag_disabled": presentation["framework_interaction_disabled"],
        },
        "boundary": {
            "battle_state_unchanged_after_render": state_before == state_after,
            "framework_owns_battle_state": false,
            "framework_owns_draw_order": false,
            "framework_owns_battle_undo": false,
        },
        "input": {
            "mouse_command": mouse_command,
            "keyboard_command": keyboard_command,
            "gamepad_command": gamepad_command,
            "all_paths_equal": JSON.stringify(mouse_command) == JSON.stringify(keyboard_command)
                and JSON.stringify(mouse_command) == JSON.stringify(gamepad_command),
            "command_log_size": router.command_log.size(),
        },
        "result": "PASS",
    }

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://result/runtime"))
    var file := FileAccess.open("res://result/runtime/phase_e_summary.json", FileAccess.WRITE)
    if file == null:
        _fail("Could not write Phase E summary", 13)
        return
    file.store_string(JSON.stringify(summary, "  "))
    file.close()

    print("[P0-3:E] SUMMARY | " + JSON.stringify(summary))
    print("[P0-3:E] INPUT ROUTING PASS")
    print("[P0-3:E] PRESENTATION BOUNDARY PASS")
    print("[P0-3:E] PASS")
    quit(0)

func _fail(message: String, code: int) -> void:
    push_error(message)
    quit(code)
