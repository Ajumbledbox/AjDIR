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

import hashlib
import shutil
from datetime import datetime
from pathlib import Path
from xml.etree import ElementTree

import common
from asset_hash import sha256_file
from audit_registry import (
    allocate_id,
    append_asset,
    append_directories,
    asset_audit_path,
    asset_registry_path,
    directory_audit_path,
    directory_entry,
    directory_registry_path,
    require_schema,
    warehouse_lock,
)
from common import AjDIRError, relative_to_root, require_directory, resolve_core_relative, validate_category_name, validate_path_length
from integrity_checkpoint import complete_checkpoint, create_checkpoint, restore_checkpoint
from registry_append import serialize_fragment


RECORDS_DIRECTORY = "records"


def local_timestamp() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def next_record_name(records: Path) -> str:
    number = 1
    while (records / f"record-{number:06d}").exists():
        number += 1
    return f"record-{number:06d}"


def existing_asset_path(entry: ElementTree.Element) -> Path:
    value = entry.findtext("path") or ""
    prefix = "core\\"
    if not value.startswith(prefix):
        raise AjDIRError(f"The asset registry contains an invalid path: {value}")
    relative = value[len(prefix):]
    return resolve_core_relative(relative.replace("\\", "/"))


def content_equal(source: Path | bytes, existing: Path, chunk_size: int = 1024 * 1024) -> bool:
    if isinstance(source, bytes):
        return existing.is_file() and existing.read_bytes() == source
    if not existing.is_file() or source.stat().st_size != existing.stat().st_size:
        return False
    with source.open("rb") as left, existing.open("rb") as right:
        while True:
            left_block = left.read(chunk_size)
            right_block = right.read(chunk_size)
            if left_block != right_block:
                return False
            if not left_block:
                return True


def find_duplicate(entries: list[ElementTree.Element], sha256: str, source: Path | bytes) -> ElementTree.Element | None:
    for entry in entries:
        if (entry.findtext("hash") or "").upper() != sha256.upper():
            continue
        existing = existing_asset_path(entry)
        if content_equal(source, existing):
            return entry
    return None


def asset_element(identifier: str, filename_value: str, directory_lineage: str, path: str, sha256: str, added: str) -> ElementTree.Element:
    entry = ElementTree.Element("asset")
    ElementTree.SubElement(entry, "id").text = identifier
    ElementTree.SubElement(entry, "filename").text = filename_value
    ElementTree.SubElement(entry, "directory-lineage").text = directory_lineage
    ElementTree.SubElement(entry, "path").text = path
    ElementTree.SubElement(entry, "hash").text = sha256
    ElementTree.SubElement(entry, "date-added").text = added
    ElementTree.SubElement(entry, "date-moved-or-removed")
    ElementTree.SubElement(entry, "validity-check").text = "complete"
    return entry


def create_record(category_value: str, name_value: str | None, source: Path | None, typed_content: str | None = None) -> dict:
    common.initialize_core()
    category = resolve_core_relative(category_value)
    require_directory(category, "Selected category")

    if typed_content is None:
        if source is None or not source.is_file():
            raise AjDIRError(f"The selected asset does not exist: {source}")
        filename_value = source.name
        physical_filename = source.name
        duplicate_source: Path | bytes = source
        incoming_hash = sha256_file(source)
    else:
        filename_value = validate_category_name(name_value or "")
        physical_filename = filename_value + ".txt"
        typed_bytes = typed_content.encode("utf-8")
        duplicate_source = typed_bytes
        incoming_hash = hashlib.sha256(typed_bytes).hexdigest().upper()

    record: Path | None = None
    records: Path | None = None
    records_was_created = False
    checkpoint_created = False
    try:
        with warehouse_lock():
            directory_path = directory_registry_path()
            asset_path = asset_registry_path()
            directory_entries = require_schema(directory_path, "directory")
            asset_entries = require_schema(asset_path, "asset")
            audit_category = directory_audit_path(category)
            category_entry = next((entry for entry in directory_entries if entry.findtext("path") == audit_category), None)
            if category_entry is None:
                raise AjDIRError(f"The directory registry has no entry for: {audit_category}")
            category_identity = {
                "id": category_entry.findtext("id") or "",
                "lineage": category_entry.findtext("lineage") or "",
            }
            duplicate = find_duplicate(asset_entries, incoming_hash, duplicate_source)
            if duplicate is not None:
                raise AjDIRError(
                    "This asset content already exists. "
                    f"Asset ID: {duplicate.findtext('id') or ''}; Stored asset: {duplicate.findtext('path') or ''}"
                )
            used = {
                value
                for entry in directory_entries + asset_entries
                if (value := entry.findtext("id"))
            }
            directory_before = directory_path.read_bytes()
            asset_before = asset_path.read_bytes()
            create_checkpoint()
            checkpoint_created = True

            records = category / RECORDS_DIRECTORY
            records_was_created = not records.exists()
            if records.exists():
                require_directory(records, "Records directory")
            else:
                validate_path_length(records)
                records.mkdir()
            record = records / next_record_name(records)
            asset_directory = record / "asset"
            destination = asset_directory / physical_filename
            validate_path_length(destination)
            asset_directory.mkdir(parents=True)
            if typed_content is None:
                shutil.copy2(source, destination)
            else:
                destination.write_bytes(typed_content.encode("utf-8"))
            stored_hash = sha256_file(destination)
            if stored_hash != incoming_hash:
                raise AjDIRError("The stored asset did not match the source SHA-256 hash.")

            timestamp = local_timestamp()
            directory_records: list[tuple[str, str, str]] = []

            if records_was_created:
                records_id = allocate_id(used)
                records_lineage = f'{category_identity["lineage"]}.{records_id}'
                directory_records.append((records_id, records_lineage, directory_audit_path(records)))
            else:
                records_audit_path = directory_audit_path(records)
                records_entry = next(
                    (entry for entry in directory_entries if entry.findtext("path") == records_audit_path),
                    None,
                )
                if records_entry is None:
                    raise AjDIRError(f"The directory registry has no entry for: {records_audit_path}")
                records_lineage = records_entry.findtext("lineage") or ""

            record_id = allocate_id(used)
            record_lineage = f"{records_lineage}.{record_id}"
            directory_records.append((record_id, record_lineage, directory_audit_path(record)))

            asset_directory_id = allocate_id(used)
            asset_directory_lineage = f"{record_lineage}.{asset_directory_id}"
            directory_records.append((asset_directory_id, asset_directory_lineage, directory_audit_path(asset_directory)))

            directory_verification = append_directories(directory_records)
            expected_directory = directory_before + b"".join(
                serialize_fragment(directory_entry(identifier, lineage, path))
                for identifier, lineage, path in directory_records
            )
            if directory_path.read_bytes() != expected_directory:
                raise AjDIRError("The directory registry contains an unexpected post-operation difference.")
            if not destination.is_file() or sha256_file(destination) != stored_hash:
                raise AjDIRError("The accepted asset does not exist at its recorded path with its recorded hash.")

            asset_id = allocate_id(used)
            asset_fragment = asset_element(
                asset_id, filename_value, asset_directory_lineage,
                asset_audit_path(destination), stored_hash, timestamp,
            )
            asset_verification = append_asset(asset_fragment)
            expected_asset = asset_before + serialize_fragment(asset_fragment)
            if asset_path.read_bytes() != expected_asset:
                raise AjDIRError("The asset registry contains an unexpected post-operation difference.")
            complete_checkpoint()
            checkpoint_created = False
    except Exception:
        if checkpoint_created:
            restore_checkpoint()
        if record is not None:
            shutil.rmtree(record, ignore_errors=True)
        if records_was_created and records is not None and records.exists() and not any(records.iterdir()):
            records.rmdir()
        raise

    return {
        "success": True,
        "operation": "asset_create",
        "id": asset_id,
        "filename": filename_value,
        "directory_lineage": asset_directory_lineage,
        "destination": relative_to_root(destination),
        "record": relative_to_root(record),
        "date_added": timestamp,
        "sha256": stored_hash,
        "directory_verification": directory_verification,
        "asset_verification": asset_verification,
    }
