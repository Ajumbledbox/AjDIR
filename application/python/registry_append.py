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
import os
from contextlib import contextmanager
from pathlib import Path
from xml.etree import ElementTree

from common import AjDIRError, ensure_within_core


@contextmanager
def registry_lock(path: Path):
    lock_path = path.with_name(path.name + ".lock")
    try:
        descriptor = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise AjDIRError(f"The registry is already being updated: {path}") from exc
    try:
        os.write(descriptor, str(os.getpid()).encode("ascii"))
        os.close(descriptor)
        descriptor = None
        yield
    finally:
        if 'descriptor' in locals() and descriptor is not None:
            os.close(descriptor)
        lock_path.unlink(missing_ok=True)


def serialize_fragment(element: ElementTree.Element) -> bytes:
    ElementTree.indent(element, space="  ")
    return ElementTree.tostring(element, encoding="utf-8", short_empty_elements=True) + b"\r\n"


def append_element_unlocked(path: Path, element: ElementTree.Element) -> dict:
    path = ensure_within_core(path)
    if not path.is_file():
        raise AjDIRError(f"Registry does not exist: {path}")

    suffix = serialize_fragment(element)
    old_bytes = path.read_bytes()
    old_length = len(old_bytes)
    old_hash = hashlib.sha256(old_bytes).hexdigest()

    with path.open("ab", buffering=0) as stream:
        stream.write(suffix)
        stream.flush()
        os.fsync(stream.fileno())

    new_bytes = path.read_bytes()
    if len(new_bytes) != old_length + len(suffix):
        raise AjDIRError("Registry append verification failed: resulting length is incorrect.")
    if hashlib.sha256(new_bytes[:old_length]).hexdigest() != old_hash:
        raise AjDIRError("Registry append verification failed: existing bytes changed.")
    if new_bytes[old_length:] != suffix:
        raise AjDIRError("Registry append verification failed: appended suffix is incorrect.")

    return {
        "registry": str(path),
        "old_length": old_length,
        "new_length": len(new_bytes),
        "old_prefix_sha256": old_hash,
        "entry_bytes": len(suffix),
    }
