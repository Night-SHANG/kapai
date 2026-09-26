from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    source_path = Path(args.source)
    out_dir = Path(args.out_dir)
    source = json.loads(source_path.read_text(encoding="utf-8"))
    items = source["items"]

    prototree: dict[str, dict[str, object]] = {}
    for item_id in sorted(items):
        item = items[item_id]
        prototree[item_id] = {
            "stack_size": 1,
            "max_stack_size": int(item["max_stack"]),
            "weight": float(item["weight"]),
            "source_item_id": item_id,
        }

    source_hash = hashlib.sha256(canonical_bytes(source)).hexdigest()
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "gloot_prototree.json").write_text(
        json.dumps(prototree, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (out_dir / "bridge_manifest.json").write_text(
        json.dumps(
            {
                "bridge_version": 1,
                "source_schema_version": source["schema_version"],
                "source_sha256": source_hash,
                "source_item_count": len(items),
                "generated_item_count": len(prototree),
                "generator": "scripts/build_gloot_bridge.py",
            },
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        ) + "\n",
        encoding="utf-8",
    )
    print(f"[P0-4:BRIDGE] generated {len(prototree)} prototypes source_sha256={source_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
