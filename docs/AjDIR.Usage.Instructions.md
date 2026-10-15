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
Update rule: Required header information belongs at the top of newly created
project files. Later document updates are append-only at the bottom. Timestamp
format: 2026-10-15 HH:MM:SS.
-->

# AjDIR Usage Instructions

## Start AjDIR

1.  Mount the VeraCrypt container that contains the AjDIR directory.
2.  Open the AjDIR directory.
3.  Run AjDIR.Dashboard.exe.

On first launch, read the complete liability statement and select **Accept** to
continue. Selecting **Decline** closes AjDIR. Acceptance creates `AjDIR.lic` in the
AjDIR root containing the local acceptance date and time and the computer name.

## Add Content

Select Add Content to open the entry form. Only one entry form can run at a
time. The read-only viewer may remain open while the entry form is open.

To create a top-level category:

1.  Enter the category name.
2.  Leave Nest beneath an existing category clear.
3.  Select Create Category.

To create a nested category:

1.  Select its parent in the category tree, or select Nest beneath an existing
    category and choose the parent.
2.  Enter the new category name.
3.  Select Create Category.

To add an existing file:

1.  Select the destination category.
2.  Select Select and Add Asset.
3.  Choose the file.

The stored file retains its existing filename. The original file is not moved
or deleted. AjDIR rejects a duplicate asset, verifies the stored copy by
SHA-256 and records the accepted asset in the central registries.

To create a typed text asset:

1.  Select the destination category.
2.  Select Create Typed Text Asset.
3.  Enter its name and text.
4.  Save it.

Typed content is stored as a plain .txt file using the entered name.

## View Content

Select View Content to open the read-only viewer. The viewer combines 
core\registry.xmlf and core\assets.xmlf in process memory and presents the
complete inventory, directories, assets, integrity state and selected-record
details.

Use the tree and search control to limit what is displayed. Select Close and
Clear to clear the displayed data and close the viewer. The viewer does not
change the warehouse or create a saved report.

## Invalid Content

If AjDIR finds physical content that is not accepted in the registries, it
moves that content outside the warehouse to the root-level invalid directory
and reports it.

- Open Invalid Directory opens that location for inspection.
- Manage Invalid Items can permanently delete one selected invalid item or all
  invalid items with SDelete after confirmation.

SDelete deletion is permanent. Confirm every selected item before continuing.

## Dashboard Tools

- AjFI opens the supplied file-integrity application.
- AjFI.2 File Compare asks for two files and compares their SHA-256 values.
- AjFI.2.File Information explains the comparison function.
- AjUST opens the supplied storage-speed and interface-information tool.
- Notepad++ opens the supplied portable text reader and editor.
- SumatraPDF opens the supplied Personal Information Control book.
- SDelete Information explains SDelete and provides its official information
  link.
- SDelete Files permanently deletes the selected files after a warning and
  confirmation, using one overwrite pass.
- VeraCrypt Information identifies the supplied VeraCrypt location.
- Readme opens the complete AjDIR.Readme.txt explanation.

The **Documents** menu opens the Readme, Liability, Ownership, Usage Instructions and
User Guide with the portable Notepad++ supplied in AjDIR.

## Important Limits

- Moving or removing accepted warehouse categories or assets is not currently
  provided.
- Do not manually change the central registry files.
- Do not treat the invalid directory as accepted warehouse content.
- Portable tools reduce dependence on system-installed applications but cannot
  guarantee that Windows retains no usage traces.
