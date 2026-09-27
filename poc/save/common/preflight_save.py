import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIX = ROOT / "fixtures"
EXPECTED = {
    "schema_v1.json": 1,
    "schema_v2.json": 2,
    "schema_v3.json": 3,
    "schema_v4.json": 4,
    "schema_missing_id_v1.json": 1,
}
FORBIDDEN_KEYS = {"node", "node_path", "scene_instance", "object_reference", "plugin_runtime_object", "resource_path"}

def walk(value, path="root"):
    if isinstance(value, dict):
        for k, v in value.items():
            if str(k).lower() in FORBIDDEN_KEYS:
                raise AssertionError(f"forbidden DTO key {path}.{k}")
            walk(v, f"{path}.{k}")
    elif isinstance(value, list):
        for i, v in enumerate(value):
            walk(v, f"{path}[{i}]")

for name, version in EXPECTED.items():
    p = FIX / name
    if not p.exists():
        raise SystemExit(f"[P0-6:PRE] missing fixture: {name}")
    data = json.loads(p.read_text(encoding="utf-8"))
    if data.get("schema_version") != version:
        raise SystemExit(f"[P0-6:PRE] {name} schema mismatch")
    walk(data)

v3 = json.loads((FIX / "schema_v3.json").read_text(encoding="utf-8"))
assert v3["expedition"]["threat"] == 58
assert v3["battle"]["turn"] == 7
assert len(v3["characters"]) == 8
assert len(v3["inventory"]["stacks"]) == 10
assert len(v3["rng_streams"]) == 5
print("[P0-6:PRE] PASS | fixtures=5 | schema=1..4 | DTO refs=stable-id-only")
