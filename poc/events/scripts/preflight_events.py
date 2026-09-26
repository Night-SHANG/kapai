from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

CONDITIONS = {
    "HasCharacter", "PartyHasTag", "HasItem", "ItemCountAtLeast", "HasResearch",
    "ResourceAtLeast", "ThreatRange", "LocationState", "WorldFlag",
    "EventSeen", "EventNotSeen", "ALL", "ANY", "NOT",
}

COMMANDS = {
    "AddResource", "RemoveResource", "AddItem", "RemoveItem", "ChangeThreat",
    "SetWorldFlag", "SetLocationState", "DiscoverLocation", "UnlockRoute",
    "DamageCharacter", "ApplyInjury", "StartBattle", "RestoreFacility",
    "UnlockArchive",
}

CUE_RE = re.compile(r"^\s*~\s+([A-Za-z0-9_]+)\s*$")
MUTATION_LINE_RE = re.compile(r"^\s*(?:\$>|set\s+|do\s+)")
INLINE_MUTATION_RE = re.compile(r"\[\$>>?")

def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def require_ref(value: str, allowed: set[str], label: str):
    if value not in allowed:
        raise ValueError(f"{label} references unknown id: {value}")

def validate_condition(condition: dict, manifest: dict, event_ids: set[str]):
    ctype = condition.get("type")
    if ctype not in CONDITIONS:
        raise ValueError(f"Unknown condition type: {ctype}")
    args = condition.get("args", {})
    if ctype == "HasCharacter":
        require_ref(args.get("character_id", ""), set(manifest["characters"]), ctype)
    elif ctype == "PartyHasTag":
        require_ref(args.get("tag", ""), set(manifest["party_tags"]), ctype)
    elif ctype in {"HasItem", "ItemCountAtLeast"}:
        require_ref(args.get("item_id", ""), set(manifest["items"]), ctype)
    elif ctype == "HasResearch":
        require_ref(args.get("research_id", ""), set(manifest["research"]), ctype)
    elif ctype == "ResourceAtLeast":
        require_ref(args.get("resource_id", ""), set(manifest["resources"]), ctype)
    elif ctype == "LocationState":
        require_ref(args.get("location_id", ""), set(manifest["locations"]), ctype)
    elif ctype == "WorldFlag":
        require_ref(args.get("flag", ""), set(manifest["world_flags"]), ctype)
    elif ctype in {"EventSeen", "EventNotSeen"}:
        require_ref(args.get("event_id", ""), event_ids, ctype)
    elif ctype in {"ALL", "ANY"}:
        nested = args.get("conditions", [])
        if not isinstance(nested, list) or not nested:
            raise ValueError(f"{ctype} must contain at least one nested condition")
        for child in nested:
            validate_condition(child, manifest, event_ids)
    elif ctype == "NOT":
        child = args.get("condition")
        if not isinstance(child, dict):
            raise ValueError("NOT must contain one nested condition")
        validate_condition(child, manifest, event_ids)

def validate_command(command: dict, manifest: dict):
    ctype = command.get("type")
    if ctype not in COMMANDS:
        raise ValueError(f"Unknown command type: {ctype}")
    args = command.get("args", {})
    if ctype in {"AddResource", "RemoveResource"}:
        require_ref(args.get("resource_id", ""), set(manifest["resources"]), ctype)
    elif ctype in {"AddItem", "RemoveItem"}:
        require_ref(args.get("item_id", ""), set(manifest["items"]), ctype)
    elif ctype == "SetWorldFlag":
        require_ref(args.get("flag", ""), set(manifest["world_flags"]), ctype)
    elif ctype in {"SetLocationState", "DiscoverLocation"}:
        require_ref(args.get("location_id", ""), set(manifest["locations"]), ctype)
    elif ctype == "UnlockRoute":
        require_ref(args.get("route_id", ""), set(manifest["routes"]), ctype)
    elif ctype in {"DamageCharacter", "ApplyInjury"}:
        require_ref(args.get("character_id", ""), set(manifest["characters"]), ctype)
    elif ctype == "StartBattle":
        require_ref(args.get("encounter_id", ""), set(manifest["encounters"]), ctype)
    elif ctype == "RestoreFacility":
        require_ref(args.get("facility_id", ""), set(manifest["facilities"]), ctype)
    elif ctype == "UnlockArchive":
        require_ref(args.get("archive_id", ""), set(manifest["archives"]), ctype)

def condition_can_be_structurally_reachable(condition: dict, self_produced_flags: set[str], manifest: dict) -> bool:
    ctype = condition.get("type")
    args = condition.get("args", {})
    if ctype == "WorldFlag" and args.get("value", True) is True:
        flag = args.get("flag", "")
        if flag in self_produced_flags and not bool(manifest.get("initial_world_flags", {}).get(flag, False)):
            return False
    if ctype == "ALL":
        return all(condition_can_be_structurally_reachable(x, self_produced_flags, manifest) for x in args.get("conditions", []))
    if ctype == "ANY":
        return any(condition_can_be_structurally_reachable(x, self_produced_flags, manifest) for x in args.get("conditions", []))
    if ctype == "NOT":
        return True
    return True

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()

    events = load_json(root / "fixtures" / "events.json")
    manifest = load_json(root / "fixtures" / "content_manifest.json")
    localization = load_json(root / "fixtures" / "localization_en.json")

    if not isinstance(events, list) or not events:
        raise ValueError("events.json must contain a non-empty array")

    event_ids = [event.get("id", "") for event in events]
    if any(not x for x in event_ids) or len(event_ids) != len(set(event_ids)):
        raise ValueError("Event IDs must be non-empty and unique")
    event_id_set = set(event_ids)

    for event in events:
        event_id = event["id"]
        if event.get("repeat_policy") not in {"once", "repeat", "cooldown"}:
            raise ValueError(f"{event_id}: invalid repeat_policy")
        if event.get("repeat_policy") == "cooldown" and int(event.get("cooldown_cycles", 0)) <= 0:
            raise ValueError(f"{event_id}: cooldown event needs cooldown_cycles > 0")
        if event.get("name_key") not in localization:
            raise ValueError(f"{event_id}: missing name localization key")
        for location_id in event.get("location_filters", []):
            require_ref(location_id, set(manifest["locations"]), f"{event_id}.location_filter")
        for region_id in event.get("region_filters", []):
            require_ref(region_id, set(manifest["regions"]), f"{event_id}.region_filter")
        for condition in event.get("availability_conditions", []):
            validate_condition(condition, manifest, event_id_set)

        dialogue_path = root / event["dialogue_resource"].replace("res://", "")
        if not dialogue_path.exists():
            raise ValueError(f"{event_id}: missing dialogue file {dialogue_path}")
        dialogue_text = dialogue_path.read_text(encoding="utf-8")
        cues = {m.group(1) for m in map(CUE_RE.match, dialogue_text.splitlines()) if m}
        if event.get("dialogue_intro") not in cues:
            raise ValueError(f"{event_id}: missing dialogue intro cue")
        for line_no, line in enumerate(dialogue_text.splitlines(), start=1):
            if MUTATION_LINE_RE.search(line) or INLINE_MUTATION_RE.search(line):
                raise ValueError(f"{event_id}: gameplay mutation forbidden in dialogue at line {line_no}")

        options = event.get("options", [])
        option_ids = [option.get("option_id", "") for option in options]
        if not options or any(not x for x in option_ids) or len(option_ids) != len(set(option_ids)):
            raise ValueError(f"{event_id}: option IDs must be non-empty and unique")

        self_produced_flags = {
            cmd.get("args", {}).get("flag", "")
            for option in options
            for cmd in option.get("commands", [])
            if cmd.get("type") == "SetWorldFlag"
        }

        structurally_reachable = False
        for option in options:
            if option.get("text_key") not in localization:
                raise ValueError(f"{event_id}/{option['option_id']}: missing localization key")
            if option.get("dialogue_branch") not in cues:
                raise ValueError(f"{event_id}/{option['option_id']}: missing dialogue cue")
            for condition in option.get("conditions", []):
                validate_condition(condition, manifest, event_id_set)
            for command in option.get("commands", []):
                validate_command(command, manifest)
            for outcome, commands in option.get("continuations", {}).items():
                if outcome not in {"win", "retreat", "wipe"}:
                    raise ValueError(f"{event_id}/{option['option_id']}: invalid battle outcome {outcome}")
                for command in commands:
                    validate_command(command, manifest)
            if all(condition_can_be_structurally_reachable(c, self_produced_flags, manifest)
                   for c in option.get("conditions", [])):
                structurally_reachable = True

        if event.get("critical", False) and not structurally_reachable:
            raise ValueError(f"{event_id}: critical event has no structurally reachable option")

    print(f"[P0-5:PRE] PASS | events={len(events)} | conditions={len(CONDITIONS)} | commands={len(COMMANDS)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
