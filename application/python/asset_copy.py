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

from asset_records import create_record
from common import (
    configure_utf8_output,
    emit,
    fail,
)


def copy_asset(category_value: str, source_value: str) -> dict:
    source = Path(source_value).resolve()
    return create_record(category_value, None, source)


def main() -> None:
    configure_utf8_output()
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", required=True)
    parser.add_argument("--source", required=True)
    arguments = parser.parse_args()
    try:
        emit(copy_asset(arguments.category, arguments.source))
    except Exception as exc:
        fail("asset_copy", exc)


if __name__ == "__main__":
    main()
