extends SceneTree

const REGISTRY_PATH := "res://data/cards_registry.tres"

func _init() -> void:
    var v := Engine.get_version_info()
    if int(v.get("major",-1)) != 4 or int(v.get("minor",-1)) != 7 or int(v.get("patch",-1)) != 1 or String(v.get("status","")) != "stable":
        push_error("Wrong engine: %s" % JSON.stringify(v))
        quit(2)
        return
    if not ResourceLoader.exists(REGISTRY_PATH):
        push_error("Registry not found: %s" % REGISTRY_PATH)
        quit(3)
        return
    var registry: Registry = load(REGISTRY_PATH)
    if registry.size() != 100:
        push_error("Expected 100 registry entries, got %d" % registry.size())
        quit(4)
        return
    var seen := {}
    for id in registry.get_all_string_ids():
        if seen.has(id):
            push_error("Duplicate stable ID: %s" % id)
            quit(5)
            return
        seen[id] = true
        if registry.load_entry(id) == null:
            push_error("Dangling registry entry: %s" % id)
            quit(6)
            return
    var sample = registry.load_entry(&"card_bastion_000")
    if sample == null or sample.owner_character_id != &"char_bastion":
        push_error("Sample lookup mismatch")
        quit(7)
        return
    print("[P0:YARD] PRECHECK PASS | entries=100 | sample=%s" % sample.resource_path)
    quit(0)
