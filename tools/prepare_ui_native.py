#!/usr/bin/env python3
"""Prepare only the pinned native spike packages, then build with installed SDL3."""
import argparse
from pathlib import Path
import subprocess
import tarfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = (
    ("dvui", "https://codeload.github.com/david-vanderson/dvui/tar.gz/475280a68b79aa1fae2be08c5726367b5e560943",
     "dvui-0.5.0-dev-AQFJmT37AwF2P5ABWwg6ly8f-HangicVtNDRZSE4hZoC"),
    ("accesskit", "https://github.com/AccessKit/accesskit-c/releases/download/0.23.0/accesskit-c-0.23.0.zip",
     "N-V-__8AAEFGZhErLHq9UH3Pw21WPLBLfjYaqLIboPjbQHTB"),
)


def extract_checked(archive, destination, prefix=None):
    """Only regular files/directories with paths contained by the destination."""
    with tarfile.open(archive) as source:
        for entry in source.getmembers():
            if prefix is not None:
                parts = Path(entry.name).parts
                if not parts or parts[0] != prefix:
                    raise ValueError(f"Unexpected package prefix: {entry.name}")
                entry.name = str(Path(*parts[1:]))
            target = (destination / entry.name).resolve()
            if destination.resolve() not in (target, *target.parents) or not (entry.isfile() or entry.isdir()):
                raise ValueError(f"Unsafe package entry: {entry.name}")
        source.extractall(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    storage = ROOT / ".zig-cache/ui-native-downloads"
    storage.mkdir(parents=True, exist_ok=True)
    (storage / "tmp").mkdir(exist_ok=True)
    packages = ROOT / ".zig-cache/ui-packages"
    packages.mkdir(exist_ok=True)
    for name, url, expected in PACKAGES:
        archive = storage / (name + (".zip" if url.endswith(".zip") else ".tar.gz"))
        if not archive.exists():
            partial = archive.with_suffix(archive.suffix + ".part")
            with urllib.request.urlopen(url, timeout=120) as response, partial.open("wb") as output:
                while chunk := response.read(1024 * 1024):
                    output.write(chunk)
            partial.replace(archive)
        # Zig checks canonical package content, not a transport compression hash.
        actual = subprocess.check_output(["zig", "fetch", "--global-cache-dir", str(storage), str(archive)], text=True).strip()
        if actual != expected:
            raise RuntimeError(f"{name} package hash mismatch: {actual}")
        destination = packages / expected
        marker = "build.zig" if name == "dvui" else "include/accesskit.h"
        if destination.exists() and not (destination / marker).is_file():
            # Preserve a previously generated nested layout while repairing it.
            destination.rename(storage / f"{name}-old-layout-{time.monotonic_ns()}")
        if not destination.exists():
            extract_checked(storage / "p" / (expected + ".tar.gz"), destination, prefix=expected)
        if not (destination / marker).is_file():
            raise RuntimeError(f"{name} extraction lacks {marker}")
        print(f"Verified {name}: {expected}", flush=True)
    if not args.prepare_only:
        version = subprocess.check_output(["pkg-config", "--modversion", "sdl3"], text=True).strip()
        print(f"Using installed SDL3 {version}; retain this version with measurement evidence", flush=True)
        subprocess.run(["zig", "build", "--build-file", "spikes/ui-native/build.zig", "--prefix", "zig-out",
                        "--system", str(packages), "-fno-sys=accesskit", "-Doptimize=ReleaseSafe", "-j2", "--summary", "all"],
                       cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
