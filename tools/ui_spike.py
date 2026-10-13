#!/usr/bin/env python3
"""Bundle, probe and measure UI candidates; retain evidence only in zig-out/."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import re
import shutil
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "zig-out" / "ui-spike"
CANDIDATES = ("appkit", "webview", "dvui")


def bundle(candidate, input_fixture=False):
    suffix = "-input" if input_fixture else ""
    destination = OUT / f"Zigide-{candidate}{suffix}.app"
    executable = ROOT / "zig-out" / "bin" / ("ui-native" if candidate == "dvui" else "ui-spike")
    if not executable.is_file():
        raise RuntimeError(f"Missing {executable}; build the candidate first")
    contents = destination / "Contents"
    (contents / "MacOS").mkdir(parents=True, exist_ok=True)
    (contents / "Resources").mkdir(exist_ok=True)
    shutil.copy2(executable, contents / "MacOS" / "ui-spike")
    # Include only the fixture-independent web surface, never a browser runtime.
    if candidate == "webview":
        shutil.copy2(ROOT / "src/ui/spike/web.html", contents / "Resources" / "web.html")
    if candidate == "dvui":
        frameworks = contents / "Frameworks"
        frameworks.mkdir(exist_ok=True)
        linked = subprocess.check_output(["otool", "-L", str(executable)], text=True)
        sdl = next((line.split()[0] for line in linked.splitlines()[1:] if "libSDL3" in line), None)
        if not sdl or not Path(sdl).is_file():
            raise RuntimeError("Native bundle requires a resolved installed SDL3 dylib")
        library = frameworks / Path(sdl).name
        if library.exists():
            library.chmod(library.stat().st_mode | 0o200)
        shutil.copy2(sdl, library)
        bundled_executable = contents / "MacOS/ui-spike"
        subprocess.run(["install_name_tool", "-change", sdl, "@executable_path/../Frameworks/" + library.name,
                        str(bundled_executable)], check=True)
        subprocess.run(["install_name_tool", "-id", "@rpath/" + library.name, str(library)], check=True)
        notices = contents / "Resources/ThirdPartyNotices"
        packages = ROOT / ".zig-cache/ui-packages"
        for package in packages.iterdir():
            for source in package.rglob("*"):
                if source.is_file() and (source.name.startswith("LICENSE") or source.name in ("OFL.txt", "COPYING.TXT", "COPYRIGHT.TXT")):
                    target = notices / package.name / source.relative_to(package)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
        sdl_license = Path(subprocess.check_output(["pkg-config", "--variable=prefix", "sdl3"], text=True).strip()) / "LICENSE.txt"
        if not sdl_license.is_file():
            raise RuntimeError("Installed SDL3 license missing")
        (notices / "SDL3").mkdir(parents=True, exist_ok=True)
        shutil.copy2(sdl_license, notices / "SDL3/LICENSE.txt")
        for binary in (library, bundled_executable):
            commands = subprocess.check_output(["otool", "-l", str(binary)], text=True)
            for rpath in re.findall(r"cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset", commands):
                if rpath.startswith("/opt/homebrew/"):
                    subprocess.run(["install_name_tool", "-delete_rpath", rpath, str(binary)], check=True)
        # install_name_tool changes invalidate existing ad-hoc signatures.
        subprocess.run(["codesign", "--force", "--sign", "-", str(library)], check=True)
        subprocess.run(["codesign", "--force", "--sign", "-", str(bundled_executable)], check=True)
    info = {
        "CFBundleExecutable": "ui-spike",
        "ZigideSpikeCandidate": candidate,
        "ZigideSpikeInputFixture": input_fixture,
        "CFBundleIdentifier": f"org.zigide.spike.{candidate}{suffix}",
        "CFBundleName": f"Zigide {candidate}{suffix} spike",
        "CFBundlePackageType": "APPL",
        "CFBundleVersion": "1",
        "CFBundleShortVersionString": "0.0.0",
        "NSHighResolutionCapable": True,
        "LSMinimumSystemVersion": "14.0",
    }
    with (contents / "Info.plist").open("wb") as stream:
        plistlib.dump(info, stream)
    return destination


def command(candidate, app, probe):
    args = [str(app / "Contents/MacOS/ui-spike")]
    if candidate == "webview":
        args.append("--web")
    if probe:
        args.append("--probe")
    return args


def process_memory(pid):
    """Snapshot descendant RSS. WebKit auxiliaries may be reparented: report this limit."""
    output = subprocess.check_output(["ps", "-axo", "pid=,ppid=,rss="], text=True)
    rows = [tuple(map(int, row.split())) for row in output.splitlines() if row.strip()]
    owned = {pid}
    while True:
        children = {child for child, parent, _ in rows if parent in owned}
        if children <= owned:
            break
        owned |= children
    return {
        "host_rss_bytes": sum(rss * 1024 for child, _, rss in rows if child == pid),
        "descendant_rss_bytes": sum(rss * 1024 for child, _, rss in rows if child in owned),
        "descendant_count": len(owned) - 1,
    }


def measure(candidate, app, repetitions):
    measurements = []
    for iteration in range(repetitions):
        log = OUT / f"{candidate}-offscreen-{iteration}.jsonl"
        peak = {"host_rss_bytes": 0, "descendant_rss_bytes": 0, "descendant_count": 0}
        ready_wall_ms = None
        started = time.monotonic()
        with log.open("w") as stream:
            process = subprocess.Popen(command(candidate, app, True), stdout=stream, stderr=subprocess.STDOUT)
            try:
                while process.poll() is None:
                    if time.monotonic() - started > 35:
                        raise TimeoutError(f"{candidate} exceeded 35-second probe deadline")
                    if ready_wall_ms is None:
                        for line in log.read_text().splitlines():
                            if line.startswith('{') and json.loads(line).get("event") == "ready":
                                ready_wall_ms = (time.monotonic() - started) * 1000
                                break
                    sample = process_memory(process.pid)
                    peak = {key: max(peak[key], sample[key]) for key in peak}
                    time.sleep(0.05)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
        events = []
        for line in log.read_text().splitlines():
            if line.startswith('{'):
                events.append(json.loads(line))
        if process.returncode or not any(event.get("event") == "metrics" and event.get("passed") for event in events):
            raise RuntimeError(f"{candidate} probe failed; inspect {log}")
        measurements.append({"iteration": iteration, "events": events, "process_to_ready_upper_bound_ms": ready_wall_ms, "peak_process_snapshot": peak})
    return measurements


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("bundle", "measure", "launch"))
    parser.add_argument("candidate", choices=CANDIDATES)
    parser.add_argument("--input-fixture", action="store_true", help="32 shared lines for interactive input inspection only")
    parser.add_argument("--repetitions", type=int, default=5)
    args = parser.parse_args()
    if not 1 <= args.repetitions <= 31:
        parser.error("repetitions must be between 1 and 31")
    if args.input_fixture and args.action != "launch":
        parser.error("--input-fixture is only for interactive launches")
    OUT.mkdir(parents=True, exist_ok=True)
    app = bundle(args.candidate, args.input_fixture)
    if args.action == "bundle":
        archive = app.with_suffix(".zip")
        subprocess.run(["ditto", "-c", "-k", "--keepParent", str(app), str(archive)], check=True)
        print(json.dumps({"bundle": str(app), "archive": str(archive)}))
    elif args.action == "launch":
        log = OUT / f"{args.candidate}-interactive.jsonl"
        with log.open("a") as stream:
            process = subprocess.Popen(command(args.candidate, app, False) + (["--input-fixture"] if args.input_fixture else []), stdout=stream, stderr=subprocess.STDOUT)
        print(json.dumps({"pid": process.pid, "bundle": str(app), "log": str(log)}))
    else:
        rows = measure(args.candidate, app, args.repetitions)
        modes = {event.get("build_mode") for row in rows for event in row["events"] if event["event"] == "ready"}
        if len(modes) != 1 or None in modes:
            raise RuntimeError("Candidate did not report one consistent build mode")
        report = {
            "candidate": args.candidate,
            "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
            "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)),
            "os": platform.platform(),
            "hardware": subprocess.check_output(["sysctl", "-n", "hw.model"], text=True).strip(),
            "memory_bytes": int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True)),
            "zig": subprocess.check_output(["zig", "version"], text=True).strip(),
            "build_mode": modes.pop(),
            "fixture_lines": 100000,
            "non_zig_surface_lines": {
                "shared_objective_c_bridge": (ROOT / "src/ui/spike/macos.m").read_text().count("\n") if args.candidate != "dvui" else 0,
                "html_css_javascript": (ROOT / "src/ui/spike/web.html").read_text().count("\n") if args.candidate == "webview" else 0,
            },
            "native_sdl3_version": subprocess.check_output(["pkg-config", "--modversion", "sdl3"], text=True).strip() if args.candidate == "dvui" else None,
            "bundle_bytes": sum(path.stat().st_size for path in app.rglob("*") if path.is_file()),
            "executable_sha256": hashlib.sha256((app / "Contents/MacOS/ui-spike").read_bytes()).hexdigest(),
            "limitations": ["warm launches; cold startup not measured", "scripted scrolling is not frame latency",
                             "process-to-ready is an upper bound sampled at 50ms plus ps/log-read overhead",
                             "RSS snapshots can miss reparented WebKit processes and short peaks",
                             "contract probes do not establish physical IME or VoiceOver behavior",
                             "local ad-hoc integrity signatures only; distribution signing/notarization are outside this spike"],
            "samples": rows,
        }
        report["offscreen"] = all(event.get("offscreen") for row in rows for event in row["events"] if event["event"] == "ready")
        report["limitations"].append("offscreen probes do not establish visible-window startup, physical scrolling or interactive behavior")
        path = OUT / f"{args.candidate}-measurements-offscreen.json"
        path.write_text(json.dumps(report, indent=2) + "\n")
        startups = [event["startup_ms"] for row in rows for event in row["events"] if event["event"] == "ready"]
        print(json.dumps({"candidate": args.candidate, "startup_median_ms": statistics.median(startups),
                          "bundle_bytes": report["bundle_bytes"], "evidence": str(path)}))


if __name__ == "__main__":
    main()
