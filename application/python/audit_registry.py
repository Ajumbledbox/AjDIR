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

import secrets
import string
from pathlib import Path
from xml.etree import ElementTree

import common
from common import AjDIRError
from registry_append import append_element_unlocked, registry_lock
from registry_parser import parse_fragments


IDENTIFIER_LENGTH = 6
IDENTIFIER_ALPHABET = string.ascii_letters + string.digits


def directory_registry_path() -> Path:
    return common.initialize_core()


def asset_registry_path() -> Path:
    common.initialize_core()
    return common.CORE_ROOT / common.ASSET_REGISTRY_NAME


def require_schema(path: Path, allowed_tag: str) -> list[ElementTree.Element]:
    entries = parse_fragments(path)
    unexpected = sorted({entry.tag for entry in entries if entry.tag != allowed_tag})
    if unexpected:
        raise AjDIRError(
            f"The registry uses an obsolete format and must be reset before this version can use it: {path}. "
            f"Unexpected entries: {', '.join(unexpected)}"
        )
    return entries


def directory_entries() -> list[ElementTree.Element]:
    return require_schema(directory_registry_path(), "directory")


def asset_entries() -> list[ElementTree.Element]:
    return require_schema(asset_registry_path(), "asset")


def allocate_id(used: set[str]) -> str:
    while True:
        value = "".join(secrets.choice(IDENTIFIER_ALPHABET) for _ in range(IDENTIFIER_LENGTH))
        if value not in used:
            used.add(value)
            return value


def directory_audit_path(path: Path) -> str:
    relative = path.resolve().relative_to(common.CORE_ROOT.resolve())
    if not relative.parts:
        return "core\\"
    return "core\\" + "\\".join(relative.parts) + "\\"


def asset_audit_path(path: Path) -> str:
    relative = path.resolve().relative_to(common.CORE_ROOT.resolve())
    return "core\\" + "\\".join(relative.parts)


def directory_entry(identifier: str, lineage: str, path: str) -> ElementTree.Element:
    entry = ElementTree.Element("directory")
    ElementTree.SubElement(entry, "id").text = identifier
    ElementTree.SubElement(entry, "lineage").text = lineage
    ElementTree.SubElement(entry, "path").text = path
    return entry


def append_directories(records: list[tuple[str, str, str]]) -> list[dict]:
    path = directory_registry_path()
    results = []
    for identifier, lineage, audit_path in records:
        results.append(append_element_unlocked(path, directory_entry(identifier, lineage, audit_path)))
    return results


def append_asset(entry: ElementTree.Element) -> dict:
    return append_element_unlocked(asset_registry_path(), entry)


def warehouse_lock():
    common.initialize_core()
    return registry_lock(common.CORE_ROOT / ".ajdir-audit")
