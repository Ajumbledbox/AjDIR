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

import argparse
from pathlib import Path

import common
from audit_registry import allocate_id, append_directories, asset_entries, directory_audit_path, directory_entries, warehouse_lock
from common import AjDIRError, configure_utf8_output, emit, fail, relative_to_root, require_directory, resolve_core_relative, validate_category_name, validate_path_length


def record_by_path(entries, audit_path: str):
    return next((entry for entry in entries if entry.findtext("path") == audit_path), None)


def ensure_core_identity(directories=None, assets=None) -> dict:
    common.initialize_core()
    if directories is None:
        directories = directory_entries()
    if assets is None:
        assets = asset_entries()
    existing = record_by_path(directories, "core\\")
    if existing is not None:
        return {"id": existing.findtext("id") or "", "lineage": existing.findtext("lineage") or "", "path": "core\\"}
    if directories:
        raise AjDIRError("The directory registry has entries but does not begin with the core directory.")
    used = {
        value
        for entry in directories + assets
        if (value := entry.findtext("id"))
    }
    identifier = allocate_id(used)
    append_directories([(identifier, identifier, "core\\")])
    return {"id": identifier, "lineage": identifier, "path": "core\\"}


def directory_identity(path: Path, directories) -> dict:
    audit_path = directory_audit_path(path)
    entry = record_by_path(directories, audit_path)
    if entry is None:
        raise AjDIRError(f"The directory registry has no entry for: {audit_path}")
    return {"id": entry.findtext("id") or "", "lineage": entry.findtext("lineage") or "", "path": audit_path}


def category_record(path: Path, directories) -> dict:
    identity = directory_identity(path, directories)
    return {
        "name": path.name,
        "category_id": identity["id"],
        "lineage": identity["lineage"],
        "relative_path": path.resolve().relative_to(common.CORE_ROOT.resolve()).as_posix(),
        "children": [category_record(child, directories) for child in sorted(
            (
                entry for entry in path.iterdir()
                if entry.is_dir() and entry.name != "records" and not entry.name.startswith(".ajdir-")
            ),
            key=lambda entry: entry.name.casefold(),
        )],
    }


def list_categories() -> dict:
    common.initialize_core()
    with warehouse_lock():
        directories = directory_entries()
        assets = asset_entries()
        ensure_core_identity(directories, assets)
        categories = [category_record(child, directories) for child in sorted(
            (
                entry for entry in common.CORE_ROOT.iterdir()
                if entry.is_dir() and not entry.name.startswith(".ajdir-")
            ),
            key=lambda entry: entry.name.casefold(),
        )]
    return {"success": True, "operation": "category_list", "root": str(common.CORE_ROOT), "categories": categories}


def create_category(parent_value: str, name_value: str) -> dict:
    common.initialize_core()
    with warehouse_lock():
        directories = directory_entries()
        assets = asset_entries()
        root_identity = ensure_core_identity(directories, assets)
        parent = resolve_core_relative(parent_value)
        require_directory(parent, "Selected parent category")
        parent_identity = root_identity if parent.resolve() == common.CORE_ROOT.resolve() else directory_identity(parent, directories)
        name = validate_category_name(name_value)
        destination = parent / name
        validate_path_length(destination)
        if destination.exists():
            raise AjDIRError(f"A file or category named '{name}' already exists in the selected location.")

        destination.mkdir()
        try:
            used = {
                value
                for entry in directories + assets
                if (value := entry.findtext("id"))
            }
            identifier = allocate_id(used)
            lineage = f'{parent_identity["lineage"]}.{identifier}'
            verification = append_directories([(identifier, lineage, directory_audit_path(destination))])[0]
        except Exception:
            if destination.exists() and not any(destination.iterdir()):
                destination.rmdir()
            raise

    return {
        "success": True, "operation": "category_create", "category": relative_to_root(destination),
        "parent": relative_to_root(parent), "category_id": identifier, "lineage": lineage,
        "append_verification": verification,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("list")
    create = subparsers.add_parser("create")
    create.add_argument("--parent", default="")
    create.add_argument("--name", required=True)
    return parser


def main() -> None:
    configure_utf8_output()
    arguments = build_parser().parse_args()
    try:
        emit(list_categories() if arguments.command == "list" else create_category(arguments.parent, arguments.name))
    except Exception as exc:
        fail(f"category_{arguments.command}", exc)


if __name__ == "__main__":
    main()
