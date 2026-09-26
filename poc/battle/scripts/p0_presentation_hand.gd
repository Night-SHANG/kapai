class_name P0PresentationHand
extends Hand

# The framework is deliberately presentation-only in this P0.
# Mouse/keyboard/gamepad selection is owned by BattleInputRouter.
func _update_card_states() -> void:
    for card in _held_cards:
        card.show_front = true
        card.can_be_interacted_with = false
