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
import os
import sys
from pathlib import Path


AJDIR_ROOT = Path(__file__).resolve().parents[2]
CORE_ROOT = AJDIR_ROOT / "core"
REGISTRY_NAME = "registry.xmlf"
ASSET_REGISTRY_NAME = "assets.xmlf"
MAX_PATH_LENGTH = 259


class AjDIRError(Exception):
    pass


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False))


def fail(operation: str, error: Exception | str, exit_code: int = 1) -> None:
    emit({"success": False, "operation": operation, "error": str(error)})
    raise SystemExit(exit_code)


def relative_to_root(path: Path) -> str:
    return path.resolve().relative_to(AJDIR_ROOT.resolve()).as_posix()


def ensure_within_core(path: Path) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(CORE_ROOT.resolve())
    except ValueError as exc:
        raise AjDIRError("The requested destination is outside the AjDIR core warehouse.") from exc
    return resolved


def resolve_core_relative(value: str) -> Path:
    candidate = ensure_within_core(CORE_ROOT / Path(value))
    return candidate


def validate_path_length(path: Path) -> None:
    path_text = str(path.resolve())
    if len(path_text) > MAX_PATH_LENGTH:
        raise AjDIRError(
            f"The proposed path is {len(path_text)} characters. AjDIR cannot process paths "
            f"longer than {MAX_PATH_LENGTH} characters. Choose another category or a shorter name."
        )


def validate_category_name(name: str) -> str:
    cleaned = name.strip()
    if not cleaned:
        raise AjDIRError("Enter a category name.")
    if cleaned in {".", ".."}:
        raise AjDIRError("The category name is not valid.")
    invalid = set('<>:"/\\|?*') | {chr(value) for value in range(32)}
    if any(character in invalid for character in cleaned):
        raise AjDIRError("The category name contains a character Windows does not allow.")
    if cleaned[-1] in {" ", "."}:
        raise AjDIRError("A category name cannot end with a space or period.")
    reserved = {
        "CON", "PRN", "AUX", "NUL",
        *(f"COM{number}" for number in range(1, 10)),
        *(f"LPT{number}" for number in range(1, 10)),
    }
    if cleaned.split(".", 1)[0].upper() in reserved:
        raise AjDIRError("The category name is reserved by Windows.")
    return cleaned


def require_directory(path: Path, label: str) -> Path:
    if not path.is_dir():
        raise AjDIRError(f"{label} does not exist: {path}")
    return path


def configure_utf8_output() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")


def initialize_core() -> Path:
    validate_path_length(CORE_ROOT)
    CORE_ROOT.mkdir(parents=True, exist_ok=True)
    registry = CORE_ROOT / REGISTRY_NAME
    validate_path_length(registry)
    registry.touch(exist_ok=True)
    assets = CORE_ROOT / ASSET_REGISTRY_NAME
    validate_path_length(assets)
    assets.touch(exist_ok=True)
    return registry
