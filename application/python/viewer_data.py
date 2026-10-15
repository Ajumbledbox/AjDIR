# (c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
# Project: Ajumbledbox Data Integrity Retention (AjDIR)
# Ownership: AjDIR and the project files created for this project are owned by
# Ajumbledbox / David Groeling unless otherwise stated in a specific file.
# Liability: AjDIR project files, plans, instructions, and future outputs
# are provided "AS IS" without warranty of any kind unless a later project document
# states otherwise.
# Third-party tooling: Third-party tooling, libraries, frameworks, and their outputs
# retain their own ownership, copyright, and licensing. AjDIR does not claim
# ownership over third-party tooling.from __future__ import annotations

import json
import sys
from pathlib import Path

import common
from asset_hash import sha256_file
from common import AjDIRError
from registry_parser import parse_fragments


DIRECTORY_FIELDS = ["id", "lineage", "path"]
ASSET_FIELDS = [
    "id", "filename", "directory-lineage", "path", "hash", "date-added",
    "date-moved-or-removed", "validity-check",
]


def disk_path(audit_path: str) -> Path:
    if audit_path == "core\\":
        return common.CORE_ROOT
    if not audit_path.startswith("core\\"):
        raise AjDIRError(f"Invalid audit path: {audit_path}")
    return common.CORE_ROOT / Path(audit_path[5:].replace("\\", "/"))


def exact_fields(entry, expected: list[str]) -> bool:
    return [child.tag for child in entry] == expected


def load_view() -> dict:
    directory_path = common.CORE_ROOT / common.REGISTRY_NAME
    asset_path = common.CORE_ROOT / common.ASSET_REGISTRY_NAME
    if not directory_path.is_file() or not asset_path.is_file():
        raise AjDIRError("The two central AjDIR registries do not exist.")

    directory_elements = parse_fragments(directory_path)
    asset_elements = parse_fragments(asset_path)
    if any(entry.tag != "directory" for entry in directory_elements):
        raise AjDIRError("The directory registry contains an unsupported entry.")
    if any(entry.tag != "asset" for entry in asset_elements):
        raise AjDIRError("The asset registry contains an unsupported entry.")

    directories = []
    directory_by_path = {}
    for entry in directory_elements:
        identifier = entry.findtext("id") or ""
        lineage = entry.findtext("lineage") or ""
        path = entry.findtext("path") or ""
        target = disk_path(path)
        state = "Present" if target.is_dir() else "Missing"
        if not exact_fields(entry, DIRECTORY_FIELDS):
            state = "Invalid fields"
        name = "core" if path == "core\\" else path.rstrip("\\").rsplit("\\", 1)[-1]
        item = {
            "id": identifier,
            "name": name,
            "lineage": lineage,
            "path": path,
            "depth": len(lineage.split(".")) if lineage else 0,
            "state": state,
        }
        directories.append(item)
        directory_by_path[path] = item

    assets = []
    for entry in asset_elements:
        identifier = entry.findtext("id") or ""
        filename = entry.findtext("filename") or ""
        lineage = entry.findtext("directory-lineage") or ""
        path = entry.findtext("path") or ""
        stored_hash = (entry.findtext("hash") or "").upper()
        target = disk_path(path)
        actual_hash = ""
        if not exact_fields(entry, ASSET_FIELDS):
            state = "Invalid fields"
        elif not target.is_file():
            state = "Missing"
        else:
            actual_hash = sha256_file(target)
            state = "Verified" if actual_hash == stored_hash else "Hash mismatch"
        parent_path = path.rsplit("\\", 1)[0] + "\\" if "\\" in path else ""
        if state == "Verified" and (
            parent_path not in directory_by_path or directory_by_path[parent_path]["lineage"] != lineage
        ):
            state = "Placement mismatch"
        assets.append({
            "id": identifier,
            "filename": filename,
            "directory_lineage": lineage,
            "path": path,
            "hash": stored_hash,
            "actual_hash": actual_hash,
            "date_added": entry.findtext("date-added") or "",
            "date_moved_or_removed": entry.findtext("date-moved-or-removed") or "",
            "state": state,
        })

    inventory = [
        {
            "type": "Directory", "id": item["id"], "name": item["name"],
            "lineage": item["lineage"], "path": item["path"], "added": "", "state": item["state"],
        }
        for item in directories
    ] + [
        {
            "type": "Asset", "id": item["id"], "name": item["filename"],
            "lineage": item["directory_lineage"], "path": item["path"],
            "added": item["date_added"], "state": item["state"],
        }
        for item in assets
    ]
    inventory.sort(key=lambda item: (item["path"].casefold(), item["type"]))
    return {"success": True, "directories": directories, "assets": assets, "inventory": inventory}


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    try:
        print(json.dumps(load_view(), ensure_ascii=False))
    except Exception as exc:
        print(json.dumps({"success": False, "error": str(exc)}, ensure_ascii=False))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
