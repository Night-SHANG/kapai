from __future__ import annotations

import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
YARD = HERE / "yard" / "data" / "cards"
DATATABLE = HERE / "datatables" / "data" / "cards_table.tres"
OUT = HERE / "result" / "runtime"
OUT.mkdir(parents=True, exist_ok=True)

TARGET_A = "card_bastion_000"
TARGET_B = "card_falcon_001"


def run(cmd, cwd=None, check=True):
    p = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if check and p.returncode != 0:
        raise RuntimeError(f"{cmd}\nSTDOUT:\n{p.stdout}\nSTDERR:\n{p.stderr}")
    return p


def line_count(path: Path) -> int:
    return len(path.read_text(encoding="utf-8").splitlines())


def replace_first_number(text: str, marker: str) -> str:
    pattern = rf"({re.escape(marker)}\s*=\s*)(\d+)"
    new, n = re.subn(pattern, lambda m: m.group(1) + str(int(m.group(2)) + 1), text, count=1)
    if n != 1:
        raise RuntimeError(f"Could not update marker {marker}")
    return new


def init_repo(root: Path):
    run(["git", "init", "-b", "main"], root)
    run(["git", "config", "user.email", "p0@example.invalid"], root)
    run(["git", "config", "user.name", "P0"], root)
    run(["git", "add", "."], root)
    run(["git", "commit", "-m", "baseline"], root)


def merge_experiment_yard() -> dict:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        shutil.copytree(YARD, root / "cards")
        init_repo(root)

        run(["git", "checkout", "-b", "branch-a"], root)
        a = root / "cards" / f"{TARGET_A}.tres"
        a.write_text(replace_first_number(a.read_text(encoding="utf-8"), "base_value"), encoding="utf-8")
        run(["git", "add", "."], root)
        run(["git", "commit", "-m", "edit A"], root)

        run(["git", "checkout", "main"], root)
        run(["git", "checkout", "-b", "branch-b"], root)
        b = root / "cards" / f"{TARGET_B}.tres"
        b.write_text(replace_first_number(b.read_text(encoding="utf-8"), "base_value"), encoding="utf-8")
        run(["git", "add", "."], root)
        run(["git", "commit", "-m", "edit B"], root)

        merge = run(["git", "merge", "branch-a", "--no-edit"], root, check=False)
        return {
            "merge_exit": merge.returncode,
            "conflict": merge.returncode != 0,
            "changed_files_branch_a": 1,
            "changed_files_branch_b": 1,
        }


def find_row_block(text: str, row_id: str) -> tuple[int, int]:
    # Godot text Resource stores dictionary entries containing row subresources.
    # We search the serialized row id key then expand to the nearest sub-resource block reference.
    idx = text.find(f'&"{row_id}"')
    if idx == -1:
        idx = text.find(f'"{row_id}"')
    if idx == -1:
        raise RuntimeError(f"Row id not found: {row_id}")
    return idx, idx


def edit_datatable_row(path: Path, row_id: str) -> None:
    text = path.read_text(encoding="utf-8")
    idx, _ = find_row_block(text, row_id)

    # Identify the SubResource id referenced by this dictionary row.
    window = text[idx: idx + 300]
    m = re.search(r'SubResource\("([^"]+)"\)', window)
    if not m:
        # Some serializer layouts place value before key; search backward too.
        window = text[max(0, idx - 300): idx + 300]
        m = re.search(r'SubResource\("([^"]+)"\)', window)
    if not m:
        raise RuntimeError(f"Could not locate subresource for {row_id}")

    sub_id = m.group(1)
    header = f'[sub_resource type="Resource" id="{sub_id}"]'
    start = text.find(header)
    if start == -1:
        raise RuntimeError(f"Subresource header not found: {sub_id}")
    end = text.find("\n[", start + len(header))
    if end == -1:
        end = len(text)

    block = text[start:end]
    block2 = replace_first_number(block, "base_value")
    path.write_text(text[:start] + block2 + text[end:], encoding="utf-8")


def merge_experiment_datatable() -> dict:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        shutil.copy2(DATATABLE, root / "cards_table.tres")
        init_repo(root)

        run(["git", "checkout", "-b", "branch-a"], root)
        edit_datatable_row(root / "cards_table.tres", TARGET_A)
        run(["git", "add", "."], root)
        run(["git", "commit", "-m", "edit A"], root)

        run(["git", "checkout", "main"], root)
        run(["git", "checkout", "-b", "branch-b"], root)
        edit_datatable_row(root / "cards_table.tres", TARGET_B)
        run(["git", "add", "."], root)
        run(["git", "commit", "-m", "edit B"], root)

        merge = run(["git", "merge", "branch-a", "--no-edit"], root, check=False)
        return {
            "merge_exit": merge.returncode,
            "conflict": merge.returncode != 0,
            "changed_files_branch_a": 1,
            "changed_files_branch_b": 1,
        }


def diff_stats_yard() -> dict:
    files = list(YARD.glob("*.tres"))
    total_lines = sum(line_count(p) for p in files)
    return {
        "entity_files": len(files),
        "total_lines": total_lines,
        "avg_lines_per_entity": round(total_lines / len(files), 2),
        "single_entity_touch_files": 1,
    }


def diff_stats_datatable() -> dict:
    return {
        "entity_files": 1,
        "total_lines": line_count(DATATABLE),
        "avg_lines_per_entity": round(line_count(DATATABLE) / 100.0, 2),
        "single_entity_touch_files": 1,
    }


def batch_balance_cost() -> dict:
    # A structural metric: how many tracked content files must be edited
    # for a 30-card balance pass.
    return {
        "yard_files_touched_for_30_cards": 30,
        "datatables_files_touched_for_30_cards": 1,
        "note": "DataTables wins bulk single-table edits; YARD wins isolation and merge locality."
    }


def main():
    result = {
        "yard": {
            "format": diff_stats_yard(),
            "merge_different_entities": merge_experiment_yard(),
        },
        "datatables": {
            "format": diff_stats_datatable(),
            "merge_different_entities": merge_experiment_datatable(),
        },
        "batch_balance": batch_balance_cost(),
    }
    out = OUT / "format_analysis.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))

    # Different-entity edits are expected to merge cleanly for YARD.
    if result["yard"]["merge_different_entities"]["conflict"]:
        raise SystemExit("YARD unexpectedly conflicted on different entity files")


if __name__ == "__main__":
    main()
