extends RefCounted

const CARD_SCENE_PATH: String = "res://addons/card-framework/card.tscn"

func render_hand(hand, card_ids: Array[String]) -> Dictionary:
    # Card Framework methods are reached through a deliberately dynamic adapter.
    # Godot 4.7.1 cannot infer := from calls on an untyped Variant, so keep the
    # boundary explicit instead of pretending the presentation plugin owns a
    # strongly typed domain object.
    var before_count: int = int(hand.get_card_count())
    if before_count > 0:
        hand.clear_cards()

    var card_scene: PackedScene = load(CARD_SCENE_PATH) as PackedScene
    if card_scene == null:
        return {"ok": false, "error": "Could not load Card Framework card.tscn"}

    for card_id: String in card_ids:
        var card = card_scene.instantiate()
        if card == null:
            return {"ok": false, "error": "Card Framework card scene did not instantiate Card"}
        card.card_name = card_id
        hand.add_card(card)

    # Let the framework perform its normal layout once, then explicitly switch
    # every rendered card into presentation-only mode. Hand._update_card_states()
    # enables interaction by default, so this adapter must turn it back off.
    hand.update_card_ui()

    var rendered_ids: Array[String] = []
    var framework_interaction_disabled: bool = true
    for raw in hand._held_cards:
        var card = raw
        card.show_front = true
        card.can_be_interacted_with = false
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.set_process(false)

        rendered_ids.append(String(card.card_name))
        if bool(card.can_be_interacted_with) or int(card.mouse_filter) != Control.MOUSE_FILTER_IGNORE:
            framework_interaction_disabled = false

    return {
        "ok": rendered_ids == card_ids,
        "count": int(hand.get_card_count()),
        "rendered_ids": rendered_ids,
        "framework_interaction_disabled": framework_interaction_disabled,
        "framework_type": String(hand.get_class()),
    }
