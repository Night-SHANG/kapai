extends SceneTree

const RegistryClass := preload("res://addons/yard/registry.gd")
const REGISTRY_PATH := "res://data/cards_registry.tres"
const SAMPLE_ID := &"card_bastion_000"

func _init() -> void:
    var registry = ResourceLoader.load(REGISTRY_PATH)
    if registry == null or not registry.get_script() == RegistryClass:
        push_error("Registry failed to load")
        quit(2)
        return

    var uid: StringName = registry.get_uid(SAMPLE_ID)
    if uid == &"":
        push_error("Stable ID no longer resolves to a UID")
        quit(3)
        return

    var path := ResourceUID.get_id_path(ResourceUID.text_to_id(uid))
    if not path.contains("/moved/"):
        push_error("UID did not follow moved resource. Resolved path: %s" % path)
        quit(4)
        return

    var card = registry.load_entry(SAMPLE_ID)
    if card == null:
        push_error("Stable ID failed to load after file move")
        quit(5)
        return

    if card.owner_character_id != &"char_bastion":
        push_error("Moved resource loaded wrong content")
        quit(6)
        return

    print("[P0:YARD] MOVE PASS | stable_id=%s | uid=%s | path=%s" % [SAMPLE_ID, uid, card.resource_path])
    quit(0)
