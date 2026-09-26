extends RefCounted
class_name P0DialogueBridge

func resolve_intro(event_def: Dictionary) -> Dictionary:
    return await _resolve_cue(event_def, String(event_def.get("dialogue_intro", "")))

func resolve_option_labels(event_def: Dictionary, option_ids: Array[String]) -> Dictionary:
    var labels: Dictionary = {}
    for option_id: String in option_ids:
        var option := _find_option(event_def, option_id)
        if option.is_empty():
            return {"ok": false, "error_code": "OPTION_NOT_FOUND", "labels": {}}
        var resolved := await _resolve_cue(event_def, String(option.get("dialogue_branch", "")))
        if not bool(resolved.get("ok", false)):
            return {"ok": false, "error_code": resolved.get("error_code", "DIALOGUE_ERROR"), "labels": {}}
        labels[option_id] = String(resolved.get("text", ""))
    return {"ok": true, "error_code": "", "labels": labels}

func select_option(option_id: String, available_option_ids: Array[String]) -> Dictionary:
    if not available_option_ids.has(option_id):
        return {"ok": false, "error_code": "OPTION_NOT_AVAILABLE", "option_id": ""}
    return {"ok": true, "error_code": "", "option_id": option_id}

func _resolve_cue(event_def: Dictionary, cue: String) -> Dictionary:
    var resource_path := String(event_def.get("dialogue_resource", ""))
    var dialogue: Variant = load(resource_path)
    if dialogue == null or not dialogue.has_method("get_next_dialogue_line"):
        return {"ok": false, "error_code": "DIALOGUE_RESOURCE_INVALID", "text": ""}
    var line: Variant = await dialogue.get_next_dialogue_line(cue)
    if line == null:
        return {"ok": false, "error_code": "DIALOGUE_CUE_MISSING", "text": ""}
    return {"ok": true, "error_code": "", "text": String(line.text)}

func _find_option(event_def: Dictionary, option_id: String) -> Dictionary:
    for raw: Variant in event_def.get("options", []):
        if raw is Dictionary:
            var option: Dictionary = raw
            if String(option.get("option_id", "")) == option_id:
                return option
    return {}
