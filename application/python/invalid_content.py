# (c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
# Project: Ajumbledbox Data Integrity Retention (AjDIR)
# Ownership: AjDIR and the project files created for this project are owned by
# Ajumbledbox / David Groeling unless otherwise stated in a specific file.
# Liability: AjDIR project files, plans, instructions, and future outputs
# are provided "AS IS" without warranty of any kind unless a later project document
# states otherwise.
# Third-party tooling: Third-party tooling, libraries, frameworks, and their outputs
# retain their own ownership, copyright, and licensing. AjDIR does not claim
# ownership over third-party tooling.# (c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
# Project: Ajumbledbox Data Integrity Retention (AjDIR)
# Created: 2026-10-13

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

import common
from audit_registry import asset_entries, directory_entries, warehouse_lock
from common import AjDIRError, configure_utf8_output, emit, fail


INVALID_ROOT_NAME = "invalid"
RESERVED_CORE_FILES = {common.REGISTRY_NAME, common.ASSET_REGISTRY_NAME}
APPLICATION_ROOT = Path(__file__).resolve().parents[2]


def invalid_root() -> Path:
    return common.AJDIR_ROOT / INVALID_ROOT_NAME


def directory_audit_path(path: Path) -> str:
    relative = path.resolve().relative_to(common.CORE_ROOT.resolve())
    return "core\\" + "\\".join(relative.parts) + "\\"


def file_audit_path(path: Path) -> str:
    relative = path.resolve().relative_to(common.CORE_ROOT.resolve())
    return "core\\" + "\\".join(relative.parts)


def unique_quarantine_path(name: str) -> Path:
    root = invalid_root()
    root.mkdir(parents=True, exist_ok=True)
    candidate = root / name
    number = 2
    while candidate.exists():
        candidate = root / f"{name}-{number}"
        number += 1
    return candidate


def scan_directory(path: Path, registered_directories: set[str], registered_assets: set[str], moved: list[dict]) -> None:
    for child in sorted(path.iterdir(), key=lambda item: item.name.casefold()):
        if child.name.startswith(".ajdir-"):
            continue
        if child.is_dir():
            audit_path = directory_audit_path(child)
            if audit_path not in registered_directories:
                destination = unique_quarantine_path(child.name)
                shutil.move(str(child), str(destination))
                moved.append({
                    "name": child.name,
                    "type": "directory",
                    "original_path": audit_path,
                    "invalid_path": str(destination),
                })
                continue
            scan_directory(child, registered_directories, registered_assets, moved)
        elif child.name not in RESERVED_CORE_FILES:
            audit_path = file_audit_path(child)
            if audit_path not in registered_assets:
                destination = unique_quarantine_path(child.name)
                shutil.move(str(child), str(destination))
                moved.append({
                    "name": child.name,
                    "type": "file",
                    "original_path": audit_path,
                    "invalid_path": str(destination),
                })


def quarantine_unregistered_content() -> dict:
    common.initialize_core()
    with warehouse_lock():
        registered_directories = {
            entry.findtext("path") or ""
            for entry in directory_entries()
        }
        registered_assets = {
            entry.findtext("path") or ""
            for entry in asset_entries()
        }
        moved: list[dict] = []
        scan_directory(common.CORE_ROOT, registered_directories, registered_assets, moved)
    return {
        "success": True,
        "operation": "quarantine_unregistered_content",
        "invalid_root": str(invalid_root()),
        "moved": moved,
    }


def secure_delete(target_value: str) -> dict:
    root = invalid_root().resolve()
    target = Path(target_value).resolve()
    try:
        target.relative_to(root)
    except ValueError as exc:
        raise AjDIRError(f"Secure deletion is restricted to the AjDIR invalid directory: {target}") from exc
    if target == root or not target.exists():
        raise AjDIRError(f"The quarantined item does not exist: {target}")

    executable = APPLICATION_ROOT / "components" / "SDelete" / "sdelete64.exe"
    if not executable.is_file():
        raise AjDIRError(f"The supplied SDelete executable is missing: {executable}")
    arguments = [str(executable), "-accepteula", "-nobanner", "-q", "-r", "-p", "1"]
    if target.is_dir():
        arguments.append("-s")
    arguments.append(str(target))
    result = subprocess.run(arguments, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    if result.returncode != 0:
        raise AjDIRError(f"SDelete failed with exit code {result.returncode}: {target}")
    if target.exists():
        if target.is_dir() and not any(target.rglob("*")):
            target.rmdir()
        else:
            raise AjDIRError(f"SDelete completed but the quarantined item still exists: {target}")
    return {"success": True, "operation": "secure_delete", "path": str(target)}


def main() -> None:
    configure_utf8_output()
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["scan", "delete"])
    parser.add_argument("--path", default="")
    arguments = parser.parse_args()
    try:
        if arguments.command == "scan":
            emit(quarantine_unregistered_content())
        else:
            if not arguments.path:
                raise AjDIRError("A quarantined item path is required for secure deletion.")
            emit(secure_delete(arguments.path))
    except Exception as exc:
        fail(f"invalid_content_{arguments.command}", exc)


if __name__ == "__main__":
    main()
