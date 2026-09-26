class_name BattleInputRouter
extends RefCounted

var selected_index: int = 0
var hand_ids: Array[String] = []
var command_log: Array[Dictionary] = []

func configure(ids: Array[String]) -> void:
    hand_ids = ids.duplicate()
    selected_index = 0

func reset_selection() -> void:
    selected_index = 0

func handle_event(event: InputEvent, mouse_card_id: String = "") -> Dictionary:
    if event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT and not mouse_card_id.is_empty():
            return _dispatch_play(mouse_card_id)

    if event is InputEventKey:
        var key := event as InputEventKey
        if not key.pressed or key.echo:
            return {}
        if key.keycode == KEY_LEFT:
            _move_selection(-1)
            return {}
        if key.keycode == KEY_RIGHT:
            _move_selection(1)
            return {}
        if key.keycode == KEY_ENTER or key.keycode == KEY_SPACE:
            return _dispatch_selected()

    if event is InputEventJoypadButton:
        var button := event as InputEventJoypadButton
        if not button.pressed:
            return {}
        if button.button_index == JOY_BUTTON_DPAD_LEFT:
            _move_selection(-1)
            return {}
        if button.button_index == JOY_BUTTON_DPAD_RIGHT:
            _move_selection(1)
            return {}
        if button.button_index == JOY_BUTTON_A:
            return _dispatch_selected()

    return {}

func _move_selection(delta: int) -> void:
    if hand_ids.is_empty():
        selected_index = 0
        return
    selected_index = posmod(selected_index + delta, hand_ids.size())

func _dispatch_selected() -> Dictionary:
    if hand_ids.is_empty():
        return {}
    return _dispatch_play(hand_ids[selected_index])

func _dispatch_play(card_id: String) -> Dictionary:
    var command := {
        "type": "PlayCard",
        "card_id": card_id,
    }
    command_log.append(command.duplicate(true))
    return command
