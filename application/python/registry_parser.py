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

from pathlib import Path
from xml.etree import ElementTree

from common import AjDIRError


def parse_fragments(path: Path) -> list[ElementTree.Element]:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    try:
        root = ElementTree.fromstring(f"<ajdir-registry>{text}</ajdir-registry>")
    except ElementTree.ParseError as exc:
        raise AjDIRError(f"Registry contains malformed XML fragments: {path}: {exc}") from exc
    return list(root)
