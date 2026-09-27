import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
paths = {
    "savestate": ROOT / "savestate" / "result" / "savestate.json",
    "enhanced": ROOT / "enhanced" / "result" / "enhanced.json",
}
results = {}
for k,p in paths.items():
    if not p.exists():
        raise SystemExit(f"missing candidate result: {p}")
    results[k] = json.loads(p.read_text(encoding="utf-8"))

s = results["savestate"]
e = results["enhanced"]

winner = "undecided"
reason = []
if s.get("hard_pass"):
    if not e.get("hard_pass"):
        winner = "savestate"
        reason.append("SaveState passes all hard Fail-Closed/recovery/schema requirements while Enhanced does not.")
    else:
        s_score = sum(bool(s.get(k)) for k in ["retained_history","automatic_recovery","newer_schema_rejected","migration_pipeline","corruption_detected"])
        e_score = sum(bool(e.get(k)) for k in ["retained_history","automatic_recovery","newer_schema_rejected","migration_pipeline","corruption_detected"])
        winner = "savestate" if s_score >= e_score else "enhanced"
        reason.append(f"Both pass hard requirements; reliability score SaveState={s_score}, Enhanced={e_score}.")
elif e.get("hard_pass"):
    winner = "enhanced"
    reason.append("Enhanced is the only candidate passing all hard requirements.")
else:
    reason.append("Neither candidate passes all hard requirements.")

out = {
    "result": "PASS" if winner != "undecided" else "NO_WINNER",
    "winner": winner,
    "reason": reason,
    "savestate": s,
    "enhanced": e,
}
dest = ROOT / "result"
dest.mkdir(parents=True, exist_ok=True)
(dest / "p0-6-save.json").write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
print("[P0-6] DECISION INPUT | " + json.dumps({"winner": winner, "savestate_hard_pass": s.get("hard_pass"), "enhanced_hard_pass": e.get("hard_pass")}))
if winner == "undecided":
    sys.exit(2)
