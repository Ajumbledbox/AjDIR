<!--
(c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
Project: Ajumbledbox Data Integrity Retention (AjDIR)
Ownership: AjDIR and the project files created for this project are owned by
Ajumbledbox / David Groeling unless otherwise stated in a specific file.
Liability: AjDIR project files, plans, instructions, and future outputs
are provided "AS IS" without warranty of any kind unless a later project document
states otherwise.
Third-party tooling: Third-party tooling, libraries, frameworks, and their outputs
retain their own ownership, copyright, and licensing. AjDIR does not claim
ownership over third-party tooling.
-->

# AjDIR User Guide

## What AjDIR Is

AjDIR is a portable method for retaining, organizing, checking and retrieving personal
information. It is intended to operate from an AjDIR directory kept inside a mounted
VeraCrypt container.

The user-owned content is stored in ordinary directories and files beneath `core`.
AjDIR records the structure and integrity information in two human-readable XMLF files:

- `core\registry.xmlf` records the managed directory structure and lineage.
- `core\assets.xmlf` records stored assets, locations, SHA-256 values and status.

The dashboard, entry form, viewer and Python scripts process this structure. The
dashboard is only the starting interface; it does not read or write the registries.

## Main Workflow

1. Mount the VeraCrypt container.
2. Run `AjDIR.Dashboard.exe`.
3. On first launch, read and accept the liability statement. AjDIR records the local
   acceptance date, time and computer name in `AjDIR.lic` at the AjDIR root.
4. Use **Add Content** to create categories and store an existing file or typed text.
5. Use **View Content** to review the warehouse and its integrity state.
6. Keep the container and its required recovery information protected according to the
   practices explained in the *Personal Information Control* book.

## Categories and Assets

Categories organize content and may be nested. The entry form shows the hierarchy as a
tree. Selecting a category can fill the existing nesting and destination controls.

An imported asset keeps its original filename. A typed asset is always stored as a
plain-text `.txt` file using the name entered by the user. AjDIR assigns permanent
internal identities and records complete placement lineage without displaying those
internal identifiers as user-facing names.

AjDIR permits one writing entry form at a time. This prevents two entry operations from
changing the registries concurrently. The viewer is read-only and may operate at the
same time.

## Integrity and Interrupted Operations

Before adding an asset, AjDIR preserves and verifies the two established registries.
It processes one asset, verifies the stored bytes against the source with SHA-256 and
accepts only the expected registry changes. A completed asset record has a final exact
validity marker.

If an addition is interrupted or incomplete, startup returns the warehouse to the
verified state from before that attempt. The failed operation is not completed or
accepted automatically. Physical content not represented by the accepted registries is
moved to the root-level `invalid` directory for the user's inspection and decision.

## Read-Only Viewer

The viewer reads both registries and validates the recorded structure and asset hashes.
It offers complete-inventory, directory and asset views, tree scope, search, integrity
state and selected-record details. Its display data exists only in the viewer process.
Closing with **Close and Clear** clears the controls and ends that process.

## Supplied Book and Tools

- *Personal Information Control* explains the broader retention, recovery, VeraCrypt
  and secure-deletion method.
- **AjFI** is the supplied full file-integrity application.
- **AjFI.2 File Compare** compares two files by SHA-256 when they are expected to be
  identical.
- **AjUST** helps explain storage-device speed and interface behavior.
- **Notepad++** provides a portable local text reader and editor.
- **SumatraPDF** provides a portable way to read the supplied book.
- **SDelete** provides confirmed permanent deletion for selected files and invalid
  content. It must be used carefully.
- The supplied **VeraCrypt** files remain third-party software and are available when
  the user requires that copy.

Portable tools reduce reliance on software installed across the computer. They do not
guarantee that the operating system creates no usage records or remnants.

## User Responsibility

The user chooses what to retain, how to organize it, when to mount or dismount the
container, how to protect credentials and recovery information, and whether to
permanently delete exposed originals. SDelete actions cannot be undone.

Do not manually rewrite the central registries or place unregistered content inside the
warehouse. Moving and removing accepted warehouse entries is not currently provided.

For step-by-step operation, read `AjDIR.Usage.Instructions.md`. For the complete
dashboard and component explanation, use the dashboard **Readme** button to open
`AjDIR.Readme.txt`. The dashboard **Documents** menu opens the Readme, Liability,
Ownership, Usage Instructions and User Guide with the portable Notepad++ supplied in
AjDIR.
