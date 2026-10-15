# (c) 2013-2026 David Groeling / Ajumbledbox. All rights reserved.
# Project: Ajumbledbox File Integrity 2 file hash Compare toolAjFI.2.file (AjFI.2F)
# Ownership: AjFI.2F and the project files created for this project are owned by
# Ajumbledbox / David Groeling unless otherwise stated in a specific file.
# Liability: AjFI.2F project files, plans, instructions, and future software outputs
# are provided "AS IS" without warranty of any kind unless a later project document
# states otherwise.
# Third-party tooling: Third-party tooling, libraries, frameworks, and their outputs
# retain their own ownership, copyright, and licensing. AjFI.2F does not claim
# ownership over third-party tooling.

import hashlib
import threading
import time
import os
import sys
from datetime import datetime

def format_size(bytes_val):
    for unit in ["B", "KB", "MB", "GB"]:
        if bytes_val < 1024:
            return f"{bytes_val:.1f}{unit}"
        bytes_val /= 1024
    return f"{bytes_val:.1f}TB"

def format_speed(bytes_per_sec):
    return format_size(bytes_per_sec) + "/s"

def hash_file(path, algo, chunk_size, result, key, progress, total_size):
    h = hashlib.new(algo)
    bytes_read = 0
    with open(path, "rb") as f:
        while chunk := f.read(chunk_size):
            h.update(chunk)
            bytes_read += len(chunk)
            progress[key] = bytes_read
    result[key] = h.hexdigest()
    progress[key] = total_size

def print_progress(progress, sizes, stop_event):
    labels = list(progress.keys())
    bar_width = 30

    while not stop_event.is_set():
        lines = []
        for label in labels:
            done = progress[label]
            total = sizes[label]
            pct = (done / total * 100) if total else 0
            filled = int(bar_width * pct / 100)
            bar = "#" * filled + "-" * (bar_width - filled)
            lines.append(f"{label}: [{bar}] {pct:5.1f}%  {format_size(done)}/{format_size(total)}")

        sys.stdout.write("\r" + "\n".join(lines) + "\033[F" * (len(lines) - 1))
        sys.stdout.flush()
        time.sleep(0.5)

    lines = []
    for label in labels:
        done = progress[label]
        total = sizes[label]
        pct = (done / total * 100) if total else 0
        filled = int(bar_width * pct / 100)
        bar = "#" * filled + "-" * (bar_width - filled)
        lines.append(f"{label}: [{bar}] {pct:5.1f}%  {format_size(done)}/{format_size(total)}")
    print("\r" + "\n".join(lines))

def write_hash_log(path1, path2, size1, size2, results, algo, elapsed, match, log_path):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with open(log_path, "w", encoding="utf-8") as f:
        f.write("HASH VERIFICATION LOG\n")
        f.write("=" * 60 + "\n")
        f.write(f"Date/time: {timestamp}\n")
        f.write(f"Hash algorithm: {algo}\n")
        f.write(f"Time taken: {elapsed:.1f}s\n")
        f.write(f"Result: {'MATCH' if match else 'MISMATCH'}\n")
        f.write("=" * 60 + "\n\n")

        f.write("File 1:\n")
        f.write(f"  Path: {os.path.abspath(path1)}\n")
        f.write(f"  Size: {size1} bytes ({format_size(size1)})\n")
        f.write(f"  Hash ({algo}): {results['File 1']}\n\n")

        f.write("File 2:\n")
        f.write(f"  Path: {os.path.abspath(path2)}\n")
        f.write(f"  Size: {size2} bytes ({format_size(size2)})\n")
        f.write(f"  Hash ({algo}): {results['File 2']}\n")

    print(f"\nHash log written to: {log_path}")

def compare_files(path1, path2, algo="sha256", chunk_size=64 * 1024 * 1024):
    size1 = os.path.getsize(path1)
    size2 = os.path.getsize(path2)

    results = {}
    progress = {"File 1": 0, "File 2": 0}
    sizes = {"File 1": size1, "File 2": size2}

    stop_event = threading.Event()
    progress_thread = threading.Thread(target=print_progress, args=(progress, sizes, stop_event))
    progress_thread.start()

    start = time.time()

    t1 = threading.Thread(target=hash_file, args=(path1, algo, chunk_size, results, "File 1", progress, size1))
    t2 = threading.Thread(target=hash_file, args=(path2, algo, chunk_size, results, "File 2", progress, size2))

    t1.start()
    t2.start()
    t1.join()
    t2.join()

    stop_event.set()
    progress_thread.join()

    elapsed = time.time() - start
    total_bytes = size1 + size2
    speed = total_bytes / elapsed if elapsed > 0 else 0

    print(f"\nAlgorithm: {algo}")
    print(f"File 1 hash: {results['File 1']}")
    print(f"File 2 hash: {results['File 2']}")
    print(f"Time: {elapsed:.1f}s   Combined throughput: {format_speed(speed)}")

    match = results["File 1"] == results["File 2"]
    if match:
        print("\nMATCH: files are identical")
    else:
        print("\nMISMATCH: files differ")

    log_filename = f"hash_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    write_hash_log(path1, path2, size1, size2, results, algo, elapsed, match, log_filename)

if __name__ == "__main__":
    try:
        if len(sys.argv) == 3:
            path1 = sys.argv[1]
            path2 = sys.argv[2]
            print(f"First file: {path1}")
            print(f"Second file: {path2}")
        else:
            path1 = input("Path to first file: ").strip().strip('"')
            path2 = input("Path to second file: ").strip().strip('"')

        if not os.path.isfile(path1):
            print(f"File not found: {path1}")
            input("\nPress Enter to exit...")
            sys.exit(1)
        if not os.path.isfile(path2):
            print(f"File not found: {path2}")
            input("\nPress Enter to exit...")
            sys.exit(1)

        compare_files(path1, path2, algo="sha256")

    except Exception as e:
        print(f"\nERROR: {e}")

    input("\nPress Enter to exit...")