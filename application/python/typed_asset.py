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
import sys

from asset_records import create_record
from common import configure_utf8_output, emit, fail


def create_typed_asset(category: str, name: str, content: str) -> dict:
    result = create_record(category, name, None, typed_content=content)
    result["operation"] = "typed_asset_create"
    return result


def main() -> None:
    configure_utf8_output()
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", required=True)
    parser.add_argument("--name", required=True)
    arguments = parser.parse_args()
    try:
        emit(create_typed_asset(arguments.category, arguments.name, sys.stdin.read()))
    except Exception as exc:
        fail("typed_asset_create", exc)


if __name__ == "__main__":
    main()
