<!--
(c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
Project: Ajumbledbox File Integrity 2 file hash Compare toolAjFI.2.file (AjFI.2F)
Ownership: AjFI.2F and the project files created for this project are owned by
Ajumbledbox / David Groeling unless otherwise stated in a specific file.
Liability: AjFI.2F project files, plans, instructions, and future software outputs
are provided "AS IS" without warranty of any kind unless a later project document
states otherwise.
Third-party tooling: Third-party tooling, libraries, frameworks, and their outputs
retain their own ownership, copyright, and licensing. AjFI.2F does not claim
ownership over third-party tooling.
format: 2026-07-30 HH:MM:SS.
-->

# AjFI.2F - 2 File Hash Comparison

## * Important Notes: 
- The script has no pause or resume feature. If you stop it, you must start the comparison again.
- If you are hashing a Virtual Drive of sorts do not run this script from within such a container.
- It is important to understand that the size of the file will play a part in how long this takes.
- Files that are small to a few million bytes in size in most cases will finish in a few seconds to just a few minutes.
- Files / Containers that are 10's of million bytes or gigabyte etc. Dependging can take up a lot of time even into the hours.
- Files that are on either an installed HDD platter will be slower then an installed SSD NVME.
- If you are comparing from one usb to another usb. Speeds are subject to the cable the port type the enclosure of the usb ...

## What you need to run this script

- **Python 3.8 or newer** installed. On Windows, check with `py --version` in Command Prompt or PowerShell.
- The Python script saved as a `.py` file, for example `compare_files.py`.
- Read access to both files being compared and write access to the directory from which you run the script, where it creates its log.
- A terminal for the progress display. No third-party Python packages, internet connection, or administrator privileges are required for ordinary files.

## What it does

The script computes a SHA-256 hash for each of two files and compares the resulting hashes. It shows progress for both files, then prints their hashes, elapsed time, combined reading throughput, and a MATCH or MISMATCH result. It also writes a text log containing the result, file paths, sizes, and hashes.

## How to run it

1. Save the supplied code as `compare_files.py`.
2. Open a terminal and change to the directory where you want the log file saved.
3. Run the script:

   ```powershell
   py C:\path\to\compare_files.py
   ```

   Or python C:\path\to\compare_files.py`
4. At the prompts, enter the path to each file. You may paste paths surrounded by double quotation marks. Press Enter after each path.
5. Read the result and the displayed log filename. Press Enter to exit.

The path to the files should be enclosed with "" ( quotes ) Example: "C:\path\to\compare_files.py"
## Results and log

- `MATCH` means both computed SHA-256 hashes are equal. This provides strong evidence that the file contents are equal. Different filenames or locations do not affect the hash.
- `MISMATCH` means the computed hashes differ, so the file contents differ.
- The log is named `hash_log_YYYYMMDD_HHMMSS.txt` and is created in the **current working directory**, which can differ from the script's directory. Its date and time come from the computer's local clock.
- Throughput is the sum of both file sizes divided by the elapsed hashing time. It is not the speed of either file individually.
- The script uses a 64 MiB read chunk for each hashing thread and reports file sizes using multiples of 1,024.

## Limits and troubleshooting

- Both paths must refer to existing regular files. If a path is wrong, the script prints `File not found` and exits after you press Enter.
- Files that change while being read can give unreliable comparison results. Compare files that are no longer being written.
- If reading fails in a hashing thread, this version may print a thread error followed by a missing-result error and may not write a log. Check read permission and that the file remains available.
- The script prints an error if it cannot write the log. A log with the same timestamp-based name can be overwritten if two runs create it in the same directory within one second.
- Empty files hash correctly, but their progress display shows `0.0%` because the displayed percentage uses a zero file size as its denominator.

