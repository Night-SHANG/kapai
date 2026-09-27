import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEP = ROOT / "third_party" / "dependencies.lock.json"
SCHEMA = ROOT / "docs" / "architecture" / "schema.lock.json"

EXPECTED_ENGINE = ("4.7.1-stable", "4.7.1.stable.official.a13da4feb")
EXPECTED_RUNTIME = {
    "yard": ("v1.2.0", "48a518b4bec03c8b5ad446f57a2b669110a1752b", "locked"),
    "card_framework": ("v1.4.0", "a74b713863adb27a22965a8e6ed039d0c4016791", "provisional_locked_pending_human_playtest"),
    "dialogue_manager": ("v4.1.0", "a719088aea342572f29b5559fd8726896c9519b2", "locked"),
    "savestate_lite": ("v2.0.0", "22b912aebbc6b52b3b31f74d3d83fec48b53870c", "locked"),
}
EXPECTED_DEV = {
    "gdunit4": ("v6.2.1", "08ffc7c65b61b1b2edd545616061a99973c13ce1", "locked"),
}
FORBIDDEN_RUNTIME_IDS = {"godot_datatables", "godot_gas", "gloot", "enhanced_save_system", "flowkit"}
HEX40 = re.compile(r"^[0-9a-f]{40}$")


def fail(message: str) -> None:
    raise SystemExit("[ARCH-LOCK] FAIL | " + message)


for path in [DEP, SCHEMA]:
    if not path.exists():
        fail(f"missing {path.relative_to(ROOT)}")

deps = json.loads(DEP.read_text(encoding="utf-8"))
schema = json.loads(SCHEMA.read_text(encoding="utf-8"))

if deps.get("manifest_version") != 1:
    fail("dependency manifest_version must be 1")

engine = deps.get("engine", {})
if (engine.get("version"), engine.get("official_build")) != EXPECTED_ENGINE:
    fail("Godot engine lock drift")
if engine.get("status") != "locked":
    fail("Godot engine must be locked")

runtime = {x.get("id"): x for x in deps.get("runtime_dependencies", [])}
dev = {x.get("id"): x for x in deps.get("development_dependencies", [])}

if set(runtime) != set(EXPECTED_RUNTIME):
    fail(f"runtime dependency set drift: {sorted(runtime)}")

if set(dev) != set(EXPECTED_DEV):
    fail(f"development dependency set drift: {sorted(dev)}")

if FORBIDDEN_RUNTIME_IDS.intersection(runtime):
    fail("P0 reference-only candidate leaked into runtime dependencies")

for dep_id, (tag, commit, status) in EXPECTED_RUNTIME.items():
    item = runtime[dep_id]
    if item.get("tag") != tag or item.get("commit") != commit or item.get("status") != status:
        fail(f"{dep_id} lock drift")
    if item.get("license") != "MIT":
        fail(f"{dep_id} license must be explicitly MIT")
    if not HEX40.match(str(item.get("commit", ""))):
        fail(f"{dep_id} commit must be exact 40-hex SHA")
    if item.get("repository", "").endswith("/main"):
        fail(f"{dep_id} must not point at floating main")

for dep_id, (tag, commit, status) in EXPECTED_DEV.items():
    item = dev[dep_id]
    if item.get("tag") != tag or item.get("commit") != commit or item.get("status") != status:
        fail(f"{dep_id} dev lock drift")
    if item.get("license") != "MIT" or not HEX40.match(str(item.get("commit", ""))):
        fail(f"{dep_id} dev dependency identity invalid")

if schema.get("contract_version") != 1:
    fail("core schema contract_version must be 1")
if schema.get("production_save_schema_version") != 1:
    fail("production save schema must start at 1")
if schema.get("definition_authority") != "YARD via project DefinitionRegistry adapter":
    fail("definition authority drift")
if schema.get("permanent_world_authority") != "WorldState":
    fail("WorldState authority drift")
if schema.get("save_backend") != "SaveState Lite v2.0.0":
    fail("save backend drift")

expected_rng = ["battle_draw", "enemy_ai", "loot", "event", "world"]
if schema.get("rng_streams") != expected_rng:
    fail("gameplay RNG stream contract drift")

rules = schema.get("persistence_rules", {})
for key in [
    "node_references_forbidden",
    "scene_instances_forbidden",
    "plugin_runtime_objects_forbidden",
    "definitions_serialized_by_id_only",
    "migrations_owned_by_project",
    "newer_schema_fail_closed",
    "missing_critical_definition_fail_closed",
    "save_only_committed_domain_state",
]:
    if rules.get(key) is not True:
        fail(f"persistence rule must remain true: {key}")

print("[ARCH-LOCK] PASS | engine=4.7.1 | runtime=4 | dev=1 | save_schema=1")
