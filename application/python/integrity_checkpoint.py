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
import importlib.util
import json
import os
import shutil
import time
from pathlib import Path
from xml.etree import ElementTree

import common
from common import AjDIRError, configure_utf8_output, emit, fail
from registry_append import serialize_fragment
from registry_parser import parse_fragments


CHECKPOINT_NAME = ".ajdir-registry-checkpoint"
PREPARING_NAME = ".ajdir-registry-checkpoint.preparing"
MANIFEST_NAME = "checkpoint.json"
LAST_KNOWN_GOOD_NAME = ".ajdir-last-known-good"
SLOT_NAMES = ("slot-a", "slot-b")
ACTIVE_NAME = "active.txt"
AJFI_CHUNK_SIZE = 64 * 1024 * 1024
APPLICATION_ROOT = Path(__file__).resolve().parents[2]


def load_ajfi_module():
    source = APPLICATION_ROOT / "components" / "AjFI.2.file" / "AjFI.2F.py"
    if not source.is_file():
        raise AjDIRError(f"The supplied AjFI.2 file-comparison script is missing: {source}")
    specification = importlib.util.spec_from_file_location("ajdir_ajfi_2file", source)
    if specification is None or specification.loader is None:
        raise AjDIRError(f"AjDIR could not load the supplied AjFI.2 script: {source}")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


def ajfi_sha256(path: Path) -> str:
    module = load_ajfi_module()
    size = path.stat().st_size
    results: dict[str, str] = {}
    progress = {"AjDIR": 0}
    module.hash_file(str(path), "sha256", AJFI_CHUNK_SIZE, results, "AjDIR", progress, size)
    return results["AjDIR"].upper()


def replace_directory(source: Path, destination: Path) -> None:
    for attempt in range(5):
        try:
            os.replace(source, destination)
            return
        except PermissionError:
            if attempt == 4:
                raise
            time.sleep(0.05)


def checkpoint_path() -> Path:
    return common.CORE_ROOT / CHECKPOINT_NAME


def preparing_path() -> Path:
    return common.CORE_ROOT / PREPARING_NAME


def registry_paths() -> tuple[Path, Path]:
    common.initialize_core()
    return (
        common.CORE_ROOT / common.REGISTRY_NAME,
        common.CORE_ROOT / common.ASSET_REGISTRY_NAME,
    )


def last_known_good_root() -> Path:
    return common.CORE_ROOT / LAST_KNOWN_GOOD_NAME


def validate_snapshot(slot: Path) -> dict[str, str]:
    try:
        hashes = json.loads((slot / MANIFEST_NAME).read_text(encoding="utf-8"))
    except Exception as exc:
        raise AjDIRError(f"The last-known-good manifest is missing or unreadable: {slot}") from exc
    for name in (common.REGISTRY_NAME, common.ASSET_REGISTRY_NAME):
        snapshot = slot / name
        expected = str(hashes.get(name, "")).upper()
        if not snapshot.is_file() or not expected or ajfi_sha256(snapshot) != expected:
            raise AjDIRError(f"The last-known-good registry copy failed AjFI.2 SHA-256 validation: {snapshot}")
    return hashes


def active_snapshot() -> Path | None:
    root = last_known_good_root()
    pointer = root / ACTIVE_NAME
    if pointer.is_file():
        name = pointer.read_text(encoding="utf-8")
        if name in SLOT_NAMES:
            slot = root / name
            try:
                validate_snapshot(slot)
                return slot
            except AjDIRError:
                pass
    valid_slots = []
    for name in SLOT_NAMES:
        slot = root / name
        try:
            validate_snapshot(slot)
            valid_slots.append(slot)
        except AjDIRError:
            pass
    if not valid_slots:
        return None
    selected = max(valid_slots, key=lambda item: item.stat().st_mtime_ns)
    temporary = root / (ACTIVE_NAME + ".tmp")
    temporary.write_text(selected.name, encoding="utf-8")
    os.replace(temporary, pointer)
    return selected


def promote_current_to_last_known_good() -> dict:
    directory_registry, asset_registry = registry_paths()
    root = last_known_good_root()
    root.mkdir(exist_ok=True)
    active = active_snapshot()
    target_name = SLOT_NAMES[1] if active is not None and active.name == SLOT_NAMES[0] else SLOT_NAMES[0]
    target = root / target_name
    preparing = root / (target_name + ".preparing")
    shutil.rmtree(preparing, ignore_errors=True)
    preparing.mkdir()
    try:
        hashes: dict[str, str] = {}
        for source in (directory_registry, asset_registry):
            destination = preparing / source.name
            shutil.copy2(source, destination)
            source_hash = ajfi_sha256(source)
            copy_hash = ajfi_sha256(destination)
            if source_hash != copy_hash:
                raise AjDIRError(f"Last-known-good AjFI.2 comparison failed: {source.name}")
            hashes[source.name] = source_hash
        (preparing / MANIFEST_NAME).write_text(json.dumps(hashes, sort_keys=True), encoding="utf-8")
        validate_snapshot(preparing)
        shutil.rmtree(target, ignore_errors=True)
        replace_directory(preparing, target)
        validate_snapshot(target)
        pointer_temporary = root / (ACTIVE_NAME + ".tmp")
        pointer_temporary.write_text(target_name, encoding="utf-8")
        os.replace(pointer_temporary, root / ACTIVE_NAME)
        return {"slot": target_name, "hashes": hashes}
    except Exception:
        shutil.rmtree(preparing, ignore_errors=True)
        raise


def ensure_last_known_good() -> dict:
    active = active_snapshot()
    if active is None:
        return promote_current_to_last_known_good()
    return {"slot": active.name, "hashes": validate_snapshot(active)}


def create_checkpoint() -> dict:
    directory_registry, asset_registry = registry_paths()
    checkpoint = checkpoint_path()
    preparing = preparing_path()
    if checkpoint.exists():
        raise AjDIRError("A verified registry checkpoint from an interrupted operation requires startup recovery.")
    if preparing.exists():
        shutil.rmtree(preparing)
    preparing.mkdir()
    try:
        hashes: dict[str, str] = {}
        for source in (directory_registry, asset_registry):
            destination = preparing / source.name
            shutil.copy2(source, destination)
            source_hash = ajfi_sha256(source)
            copy_hash = ajfi_sha256(destination)
            if source_hash != copy_hash:
                raise AjDIRError(f"Registry checkpoint verification failed: {source.name}")
            hashes[source.name] = source_hash
        (preparing / MANIFEST_NAME).write_text(json.dumps(hashes, sort_keys=True), encoding="utf-8")
        replace_directory(preparing, checkpoint)
        return {"path": str(checkpoint), "hashes": hashes}
    except Exception:
        shutil.rmtree(preparing, ignore_errors=True)
        raise


def verify_checkpoint() -> dict[str, str]:
    checkpoint = checkpoint_path()
    if not checkpoint.is_dir():
        raise AjDIRError("The verified registry checkpoint is missing.")
    try:
        hashes = json.loads((checkpoint / MANIFEST_NAME).read_text(encoding="utf-8"))
    except Exception as exc:
        raise AjDIRError("The registry checkpoint manifest is missing or unreadable.") from exc
    for name in (common.REGISTRY_NAME, common.ASSET_REGISTRY_NAME):
        expected = str(hashes.get(name, "")).upper()
        backup = checkpoint / name
        if not expected or not backup.is_file() or ajfi_sha256(backup) != expected:
            raise AjDIRError(f"The verified registry checkpoint is invalid: {name}")
    return hashes


def restore_checkpoint() -> dict:
    hashes = verify_checkpoint()
    directory_registry, asset_registry = registry_paths()
    checkpoint = checkpoint_path()
    for destination in (directory_registry, asset_registry):
        source = checkpoint / destination.name
        shutil.copy2(source, destination)
        if ajfi_sha256(destination) != hashes[destination.name]:
            raise AjDIRError(f"Registry restoration verification failed: {destination.name}")
    shutil.rmtree(checkpoint)
    return {"restored": True, "registries": [directory_registry.name, asset_registry.name]}


def complete_checkpoint() -> None:
    verify_checkpoint()
    promote_current_to_last_known_good()
    shutil.rmtree(checkpoint_path())


def validate_asset_completion_flags() -> dict:
    asset_registry = common.CORE_ROOT / common.ASSET_REGISTRY_NAME
    entries = parse_fragments(asset_registry)
    invalid = []
    for entry in entries:
        if entry.tag != "asset":
            raise AjDIRError(f"The asset registry contains an unsupported entry: {entry.tag}")
        flags = entry.findall("validity-check")
        flag = flags[0] if len(flags) == 1 else None
        valid = (
            flag is not None
            and len(entry) > 0
            and entry[-1] is flag
            and flag.text == "complete"
            and not flag.attrib
            and len(flag) == 0
        )
        if not valid:
            invalid.append({
                "id": entry.findtext("id") or "",
                "path": entry.findtext("path") or "",
            })
    if invalid:
        details = "; ".join(
            f"Asset ID {item['id'] or '[missing]'} at {item['path'] or '[missing path]'}"
            for item in invalid
        )
        raise AjDIRError(
            "AjDIR found an incomplete asset operation. The final validity-check must be the last asset element "
            f"and must contain exactly 'complete'. {details}"
        )
    return {"checked": len(entries), "invalid": 0}


def asset_completion_issues() -> list[dict]:
    asset_registry = common.CORE_ROOT / common.ASSET_REGISTRY_NAME
    entries = parse_fragments(asset_registry)
    issues = []
    for entry in entries:
        if entry.tag != "asset":
            raise AjDIRError(f"The asset registry contains an unsupported entry: {entry.tag}")
        flags = entry.findall("validity-check")
        flag = flags[0] if len(flags) == 1 else None
        valid = (
            flag is not None
            and len(entry) > 0
            and entry[-1] is flag
            and flag.text == "complete"
            and not flag.attrib
            and len(flag) == 0
        )
        if not valid:
            issues.append({
                "id": entry.findtext("id") or "",
                "filename": entry.findtext("filename") or "",
                "path": entry.findtext("path") or "",
            })
    return issues


def write_entries(path: Path, entries: list[ElementTree.Element]) -> None:
    temporary = path.with_name(path.name + ".revert.tmp")
    temporary.write_bytes(b"".join(serialize_fragment(entry) for entry in entries))
    os.replace(temporary, path)


def disk_path(audit_path: str) -> Path:
    if not audit_path.startswith("core\\"):
        raise AjDIRError(f"The asset registry contains an invalid path: {audit_path}")
    return common.CORE_ROOT / Path(audit_path[5:].replace("\\", "/"))


def revert_invalid_asset(asset_id: str) -> dict:
    common.initialize_core()
    asset_registry = common.CORE_ROOT / common.ASSET_REGISTRY_NAME
    directory_registry = common.CORE_ROOT / common.REGISTRY_NAME
    assets = parse_fragments(asset_registry)
    directories = parse_fragments(directory_registry)
    matches = [entry for entry in assets if (entry.findtext("id") or "") == asset_id]
    if len(matches) != 1:
        raise AjDIRError(f"AjDIR could not uniquely identify the incomplete asset: {asset_id}")
    entry = matches[0]
    issue_ids = {item["id"] for item in asset_completion_issues()}
    if asset_id not in issue_ids:
        raise AjDIRError(f"AjDIR will not revert an asset whose validity check is complete: {asset_id}")

    filename = entry.findtext("filename") or ""
    audit_path = entry.findtext("path") or ""
    target = disk_path(audit_path)
    checkpoint_created = False
    staged_asset = None
    removed_directory_paths: list[str] = []
    try:
        create_checkpoint()
        checkpoint_created = True
        if target.exists():
            if not target.is_file():
                raise AjDIRError(f"The incomplete asset path is not a file: {audit_path}")
            staged_asset = checkpoint_path() / "reverted-asset"
            shutil.move(str(target), str(staged_asset))

        current = target.parent
        while current != common.CORE_ROOT and current.name:
            if current.name == "asset" or current.name.startswith("record-") or current.name == "records":
                if current.is_dir() and not any(current.iterdir()):
                    relative = current.resolve().relative_to(common.CORE_ROOT.resolve())
                    removed_directory_paths.append("core\\" + "\\".join(relative.parts) + "\\")
                    current.rmdir()
                    current = current.parent
                    continue
            break

        remaining_assets = [item for item in assets if item is not entry]
        removed_set = set(removed_directory_paths)
        remaining_directories = [
            item for item in directories
            if (item.findtext("path") or "") not in removed_set
        ]
        write_entries(asset_registry, remaining_assets)
        write_entries(directory_registry, remaining_directories)

        if any((item.findtext("id") or "") == asset_id for item in parse_fragments(asset_registry)):
            raise AjDIRError(f"The incomplete asset registry entry was not removed: {asset_id}")
        complete_checkpoint()
        checkpoint_created = False
        return {
            "success": True,
            "operation": "revert_invalid_asset",
            "id": asset_id,
            "filename": filename,
            "path": audit_path,
            "removed_directories": removed_directory_paths,
        }
    except Exception:
        if checkpoint_created:
            if staged_asset is not None and staged_asset.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(staged_asset), str(target))
            restore_checkpoint()
        raise


def recover_startup() -> dict:
    common.initialize_core()
    preparing = preparing_path()
    if preparing.exists():
        shutil.rmtree(preparing)
    if checkpoint_path().exists():
        result = restore_checkpoint()
        snapshot = ensure_last_known_good()
        return {"success": True, "operation": "startup_recovery", **result, "last_known_good": snapshot}
    snapshot = ensure_last_known_good()
    return {
        "success": True,
        "operation": "startup_recovery",
        "restored": False,
        "registries": [],
        "last_known_good": snapshot,
    }


def main() -> None:
    configure_utf8_output()
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["recover", "inspect", "revert"])
    parser.add_argument("--asset-id", default="")
    arguments = parser.parse_args()
    try:
        if arguments.command == "recover":
            emit(recover_startup())
        elif arguments.command == "inspect":
            common.initialize_core()
            emit({
                "success": True,
                "operation": "startup_inspection",
                "issues": asset_completion_issues(),
            })
        else:
            if not arguments.asset_id:
                raise AjDIRError("An asset ID is required for targeted rollback.")
            emit(revert_invalid_asset(arguments.asset_id))
    except Exception as exc:
        fail("startup_recovery", exc)


if __name__ == "__main__":
    main()
