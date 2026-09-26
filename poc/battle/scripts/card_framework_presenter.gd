extends RefCounted

const CARD_SCENE_PATH := "res://addons/card-framework/card.tscn"

func render_hand(hand, card_ids: Array[String]) -> Dictionary:
    var before_count := hand.get_card_count()
    if before_count > 0:
        hand.clear_cards()

    var card_scene := load(CARD_SCENE_PATH) as PackedScene
    if card_scene == null:
        return {"ok": false, "error": "Could not load Card Framework card.tscn"}

    for card_id in card_ids:
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
    var framework_interaction_disabled := true
    for raw in hand._held_cards:
        var card = raw
        card.show_front = true
        card.can_be_interacted_with = false
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.set_process(false)

        rendered_ids.append(card.card_name)
        if card.can_be_interacted_with or card.mouse_filter != Control.MOUSE_FILTER_IGNORE:
            framework_interaction_disabled = false

    return {
        "ok": rendered_ids == card_ids,
        "count": hand.get_card_count(),
        "rendered_ids": rendered_ids,
        "framework_interaction_disabled": framework_interaction_disabled,
        "framework_type": hand.get_class(),
    }
