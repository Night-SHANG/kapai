extends "res://addons/card-framework/hand.gd"

# Kept as a path-based adapter example. Phase E currently instantiates the
# framework Hand directly and disables drag interaction after each render.
func disable_framework_interaction() -> void:
    for card in _held_cards:
        card.show_front = true
        card.can_be_interacted_with = false
