class_name P0LightBattleHarness
extends RefCounted

var sync: int = 0
var queued_actions: Array[Dictionary] = []

func resolve_incoming_attack(original_target_id: StringName, original_target, guardian) -> StringName:
    var final_target_id := original_target_id
    var final_target = original_target

    if original_target != guardian and guardian.has_tag(&"Status.Intercept"):
        guardian.remove(&"status_intercept")
        final_target_id = guardian.owner_id
        final_target = guardian

    if final_target.has_tag(&"Status.Counter"):
        final_target.remove(&"status_counter")
        queued_actions.append({
            "type":"counter",
            "source_id":String(final_target.owner_id),
            "target_id":"enemy_attacker",
        })

    return final_target_id

func consume_mark_for_link(target) -> void:
    if target.has_tag(&"Status.Mark"):
        target.remove(&"status_mark")
        sync += 1
        queued_actions.append({"type":"gain_sync","amount":1})
