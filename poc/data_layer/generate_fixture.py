from __future__ import annotations

import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHARACTERS = ["char_bastion","char_falcon","char_loom","char_breacher","char_pulse","char_beacon","char_arbiter","char_echo"]
TAG_SETS = [["Attack","Ranged"],["Attack","Precision"],["Guard","Support"],["Tech","Interference"],["Attack","Heavy"],["Repair","Support"],["Formation","Support"],["Attack","Break"]]

def make_cards():
    out = []
    for i in range(100):
        owner = CHARACTERS[i % len(CHARACTERS)]
        short = owner.removeprefix("char_")
        out.append({"id":f"card_{short}_{i:03d}","owner_character_id":owner,"name_key":f"CARD_{short.upper()}_{i:03d}_NAME","description_key":f"CARD_{short.upper()}_{i:03d}_DESC","tags":TAG_SETS[i % len(TAG_SETS)],"base_value":3 + (i % 11)})
    return out

def make_simple(prefix, count, extra=None):
    extra = extra or {}
    return [{"id":f"{prefix}_{i:03d}","name_key":f"{prefix.upper()}_{i:03d}_NAME",**extra} for i in range(count)]

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True).encode("utf-8")
    path.write_bytes(raw + b"\n")
    return hashlib.sha256(raw).hexdigest()

def main():
    data = {
        "cards.json": make_cards(),
        "characters.json": [{"id":x,"name_key":f"{x.upper()}_NAME"} for x in CHARACTERS],
        "enemies.json": make_simple("enemy_test",30,{"faction_id":"legacy_war_machine"}),
        "items.json": make_simple("item_test",20,{"max_stack":99,"unit_weight":1.0}),
        "locations.json": make_simple("location_test",10,{"region_id":"region_test"}),
        "events.json": make_simple("event_test",10,{"repeat_policy":"once"}),
        "statuses.json": make_simple("status_test",10,{"max_stacks":5}),
    }
    manifest = {"fixture_version":1,"counts":{},"sha256":{}}
    for variant in ("yard","datatables"):
        out_dir = HERE / variant / "fixtures"
        for filename,payload in data.items():
            digest = write_json(out_dir / filename,payload)
            if variant == "yard":
                manifest["counts"][filename] = len(payload)
                manifest["sha256"][filename] = digest
    write_json(HERE / "fixtures" / "generated" / "manifest.json",manifest)
    print(json.dumps(manifest,indent=2))

if __name__ == "__main__": main()
