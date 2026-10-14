# ADR-0004: UI Toolkit Selection by Evidence

* Status: Accepted
* Date: 2026-08-16
* Accepted: 2026-10-14

## Context

An IDE UI needs high-quality text rendering, input methods, clipboard, accessibility, keyboard handling, multiple panels, and responsive rendering. Writing all of this from scratch would dominate the project. Choosing a web stack would accelerate UI work but weaken the goal of learning Zig and can add a large runtime. Choosing a young native Zig toolkit may expose missing IDE-grade capabilities.

## Decision

Use **DVUI** for Zigide's current production UI direction. Mourad explicitly chose
DVUI on 2026-10-14 because it is written in Zig. Start from the spike's pinned
DVUI 0.5.0-dev revision `475280a68b79aa1fae2be08c5726367b5e560943`, SDL3 integration
and AccessKit-C 0.23.0. Keep toolkit types inside the UI adapter and preserve the
toolkit-independent domain/application boundary.

This accepts an implementation direction while physical IME, VoiceOver, performance
and other qualification evidence remains incomplete. The lower preliminary DVUI
evidence score is retained below; the human choice does not rescore unobserved
behavior or qualify a release. Production integration belongs to its existing
feature tickets and is not implemented by this decision update.

A custom UI library inspired by imgui/egui and Zig philosophy remains a separate
future project. It is not started here. Replacing the accepted adapter later needs
its own reviewed decision and evidence.

The comparison spike covers:

* a window with explorer/editor/panel layout;
* rendering and scrolling of a large UTF-8 document;
* keyboard selection, clipboard, and Unicode input through an IME;
* font fallback, scale-factor changes, and accessible labels;
* a background search result delivered without blocking input;
* a distributable application bundle with measured startup time and memory.

## Candidates

Evaluate maintained native Zig libraries, direct platform adapters, and a lightweight webview approach. Concrete candidates to score in the spike, as known at proposal time:

* **Direct AppKit adapter** through Zig's C and Objective-C interop. On macOS this is the path most likely to pass IME input, font fallback, and VoiceOver accessibility, because those behaviors come from the platform. Its costs are Objective-C binding work and a per-platform adapter later.
* **Native Zig toolkits** such as `dvui`, `capy`, and the `mach` ecosystem. These maximize Zig ownership but are young; the spike must verify IDE-grade text input and accessibility rather than assume them.
* **A lightweight webview** (system WKWebView, not a bundled browser runtime). Fast UI iteration, but it weakens the Zig learning goal and moves the editor surface into web technology.

The spike should expect the IME, accessibility, and text-rendering criteria to be the discriminating tests: they are where young toolkits most often fall short, and platform adapters most often succeed. Record exact versions, licenses, maintenance health, binding complexity, and which required behaviors work. A custom GPU widget system is acceptable only if the project explicitly accepts its accessibility and text-input cost.

## Decision Criteria

Correct text input and recoverable editing outrank visual novelty. Then consider accessibility, Zig ownership, cross-platform path, dependency stability, debugging, packaging, performance, and implementation effort.

## Consequences

* Production UI work has an accepted DVUI direction; qualification failures still block milestone exit.
* Milestone 0 includes throwaway work.
* The adapter boundary protects domain code but cannot eliminate toolkit-specific layout and accessibility work.

## Validation

Retain the spike code, versions, licenses, measurements, failures and scored
comparison. Complete the remaining target-device IME, accessibility and performance
checks honestly; missing observations stay unrun. ZIT-038–ZIT-040 remain incomplete,
so ZIT-041 and Milestone 0 completion remain blocked by their declared prerequisites
even though this architectural choice is accepted.

## Spike implementation and decision gate (2026-10-13)

ZIT-034–ZIT-041 have one shared scenario and three isolated candidate adapters.
See the [spike contract and reproduction commands](../../../src/ui/spike/README.md).
The main application and its package dependency graph remain toolkit-independent.

Direct AppKit and system WKWebView build through a Zig entry point and an
Objective-C C ABI. The native candidate is DVUI 0.5.0-dev at
`475280a68b79aa1fae2be08c5726367b5e560943` (MIT), with installed SDL3 3.4.14 and
pinned static AccessKit-C 0.23.0. DVUI is selected for the native comparison because
it supports the pinned Zig 0.16 toolchain and maintained multiline/accessibility
primitives. Capy's documented macOS text controls are missing; Mach would require
a custom widget system. No custom UI framework is part of this spike.

All three adapters compile and produce local bundles. Automated AppKit probes
cover Unicode private-pasteboard round-trip, marked-text updates, commit,
cancellation and accessibility value. Web probes cover selection, composition
message deferral and stale results. DVUI probes cover full-fixture rendering and
worker delivery. These probes do not establish physical IME or VoiceOver success.
Target-device AppKit inspection exposed labels, editor text/selection, scroll
controls, focus and results, and a Unicode paste was observed. The remaining
interactive checks were blocked by the closed computer-use transport. The target
Mac initially had no Japanese IME enabled. The user subsequently added the
built-in Japanese Kana input source, whose availability was verified read-only.
The user initially requested silent testing. Later task history records explicit
permission to resume brief qualification with temporary input/VoiceOver changes,
followed by an interrupted run without completed manual qualification. No such
interaction is performed by this decision update. Arabic round-trip coverage does
not establish marked-text composition or rendered RTL correctness.

### Preliminary scored comparison

Each cell is 0 (failed/unverified), 1 (partial), or 2 (passed). Scores use the shared
weights: input 35, accessibility 25, performance 15, packaging 10, Zig ownership 10,
maintenance 5. This table scores available evidence and implementation costs,
not undocumented claims about toolkit capabilities. These are the preliminary
2026-10-13 observations, retained unchanged after the 2026-10-14 DVUI selection.

| Candidate | Input | Accessibility | Performance | Packaging | Zig ownership | Maintenance | Score / 200 | Production eligible |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AppKit | 1 | 1 | 1 | 2 | 1 | 2 | 115 | No |
| DVUI + SDL3 + AccessKit | 0 | 0 | 1 | 2 | 2 | 1 | 60 | No |
| System WKWebView | 1 | 0 | 1 | 2 | 0 | 2 | 80 | No |

At spike time, AppKit was the provisional recommendation because its input-client
probes and observed native text exposure provided the strongest evidence. Its binding
surface, platform-specific implementation and large-document layout/memory costs
remain material. DVUI offers the most Zig UI ownership but its physical composition,
font fallback and VoiceOver costs are unverified. WKWebView adds HTML/CSS/JavaScript,
asynchronous debugging and a web/native bridge; reparented WebKit processes prevent
host RSS from establishing total memory cost. The first accessibility snapshot
exposed only the outer WebView container; its label override was removed, but the
corrected tree could not be reinspected after transport loss.

Measurements and screenshots remain local evidence; generated data and logs are
not committed. `tools/ui_spike.py` retains individual samples, hardware, build mode,
executable hash, fixture, startup bounds, RSS limitations, scrolling method,
background latency and package size under ignored `zig-out/ui-spike/`. CI builds
and uploads bundles; CI does not certify physical-device input or screen-reader use.
Automated probes are now offscreen and report that mode explicitly; offscreen
timings must not replace the retained earlier visible-window observations.

**DVUI is the accepted direction as of 2026-10-14.** Remaining target-device
input/accessibility and performance observations are still required; the choice
does not complete ZIT-038–ZIT-041 or Milestone 0. The production executable is still
headless, and the production shell/editor implementation tickets remain unimplemented.
