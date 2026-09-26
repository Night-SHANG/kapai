extends SceneTree

func _init() -> void:
    var v := Engine.get_version_info()
    print("[Preflight] Engine: %s" % JSON.stringify(v))
    var ok := int(v.get("major",-1)) == 4 and int(v.get("minor",-1)) == 7 and int(v.get("patch",-1)) == 1 and String(v.get("status","")) == "stable"
    if not ok:
        push_error("Required Godot 4.7.1 stable")
        quit(2)
        return
    quit(0)
