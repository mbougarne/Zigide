# UI toolkit spike (ZIT-034–ZIT-041)

This is an isolated comparison, not the production editor. Toolkit types remain
inside `src/ui/spike`; no product-domain import or dependency is added. The
production executable remains headless. ADR-0004 now accepts DVUI as the production
direction; integration belongs to the production feature tickets, with target-device
qualification still pending. A later custom Zig UI is a separate future project.

## Shared scenario

All candidates display the same explorer, editable source view and results panel
in an 1100×760 window. The generated document has 100,000 identical Unicode lines
(4,600,000 UTF-8 bytes), Japanese text, emoji, a combining accent, final newlines,
and 100,000 `needle` matches. Search runs against the immutable shared fixture on
a worker and delivers a versioned result on the UI thread. This is intentionally
fixture search, not a production workspace search service. Stale results are
suppressed. All candidates allow edits, selection and clipboard interaction.

The clipboard contract includes Arabic text as well as Japanese, emoji and a
combining accent. Arabic Unicode round-trip is separate from rendered RTL and
marked-text composition verification.

`scenario.zig` defines behavior, fixture, result validity and scoring. Weights are
input 35, accessibility 25, performance 15, packaging 10, Zig ownership 10 and
maintenance 5. Observations score 0 (failed/unverified), 1 (partial) or 2 (passed),
for a maximum of 200. Production eligibility additionally requires fully verified
input and accessibility; an unverified observation can never open that gate.

## Build and inspect

Use pinned Zig 0.16.0 on macOS arm64, Xcode command-line tools and Python 3.9+.
Keep two build jobs to avoid competing with other projects.

```sh
zig build ui-test -j2
zig build ui-spike -Doptimize=ReleaseSafe -j2
python3 tools/ui_spike.py bundle appkit
python3 tools/ui_spike.py bundle webview
python3 tools/ui_spike.py launch appkit --input-fixture
python3 tools/ui_spike.py launch webview --input-fixture
PYTHONPYCACHEPREFIX=.zig-cache/python python3 tests/ui_spike_test.py
```

Interactive `--input-fixture` uses 32 identical shared lines to keep accessibility
inspection practical. It is prohibited for measurements, which always use the
full fixture. Bundle metadata preserves candidate identity when launched by
Finder without arguments. The system candidates share a Zig executable and a
small Objective-C C-ABI bridge. AppKit uses `NSTextView`; WebView uses system
`WKWebView` and a bundled textarea surface. The web bridge carries only ready,
edit-version and fixture-search messages. It allows only local navigation and
provides no extension API, network listener or bundled browser runtime.

## Native Zig candidate

DVUI 0.5.0-dev is pinned at
[`475280a68b79aa1fae2be08c5726367b5e560943`](https://github.com/david-vanderson/dvui/tree/475280a68b79aa1fae2be08c5726367b5e560943).
Its license is MIT; latest upstream commit observed during selection was dated
2026-10-11. It supports the repository's Zig 0.16 toolchain, multiline entry,
SDL3 and AccessKit. [Capy](https://github.com/capy-ui/capy) targets Zig 0.14.1 and
lists macOS as planned with text areas missing. [Mach](https://machengine.org/)
provides a graphics engine requiring a nominated toolchain; an IDE widget system
would require additional work. This is source-based candidate selection, not a
claim about untested behavior.

The native package graph is isolated in `spikes/ui-native/`. The preparation
script downloads only the exact DVUI source and AccessKit-C 0.23.0 release, checks
Zig content hashes, and uses a local package/cache directory. Unused SVG, parser,
file-dialog and FreeType features are disabled. The supported upstream system
integration uses an already installed SDL3; target-device evidence must record its
exact version (the development Mac has 3.4.14). Missing SDL3/pkg-config is a clear
setup blocker; the script does not install it or change the product toolchain.

```sh
pkg-config --modversion sdl3
python3 tools/prepare_ui_native.py
python3 tools/ui_spike.py bundle dvui
python3 tools/ui_spike.py launch dvui --input-fixture
```

The default upstream SDL source wrapper has eager dependencies on other
platforms. Its network fetching stalled on the target Mac. Using the supported
system SDL integration and an explicit minimal `--system` package directory avoids
that cost without modifying upstream packages. Bundling copies the resolved SDL3
dylib, rewrites only the copied files' load paths, includes upstream/font/SDL
notices and creates local ad-hoc integrity signatures. Distribution signing and
notarization require a separate packaging ticket.

## Measurements and acceptance

```sh
python3 tools/ui_spike.py measure appkit --repetitions 5
python3 tools/ui_spike.py measure webview --repetitions 5
python3 tools/ui_spike.py measure dvui --repetitions 5
```

Bundle commands also create ZIP archives with executable permissions preserved.
CI uploads these archives so downloaded bundles remain launchable.

Automated `measure`/`--probe` runs are offscreen: they neither show nor focus the
candidate window. They retain `*-measurements-offscreen.json` and clearly identify
the offscreen mode. These timings cannot certify visible-window startup or physical
scrolling. Interactive `launch` is an explicit opt-in for an uninterrupted manual
review; do not repeatedly launch/focus visible windows during automated work.

JSON/JSONL evidence and all bundles remain in ignored `zig-out/ui-spike/`.
`docs/milestones/` stays ignored and no milestone report is generated. Measurements
retain OS/hardware, build mode, executable hash, source head/dirty state, full
fixture, warm startup samples, idle host RSS, process snapshots, background delivery,
scripted scroll cost and bundle size. Process-to-ready is a sampled upper bound;
adapter startup boundaries differ. WebKit auxiliaries may be reparented and absent
from descendant RSS: host-only memory must not be presented as total WebView
memory. Scripted scrolling is not a physical frame-latency test. Shared-machine
contention, cold startup and scale-factor changes need separate observations.

The AppKit probe exercises a private pasteboard (preserving the user's clipboard),
`NSTextInputClient` marked-text update/commit/cancel, and native text exposure. The
web probe checks selection, composition deferral, final input and stale result
handling using synthetic events. These are automated contract checks, not physical
IME or VoiceOver tests. The DVUI probe reports full-fixture rendering and worker
results; it does not falsely label input or VoiceOver as verified.

For **every viable candidate**, use the same interactive fixture to:

1. Use the existing Arabic input source. Paste multiline `café 😀`, Arabic,
   Japanese and a combining accent; select with the
   keyboard, copy, replace and paste back; check newlines and grapheme rendering.
2. When a composing IME is already available and interaction is approved: update a mark, select a candidate, commit and
   cancel another composition. Watch text/selection and ensure background delivery
   does not interrupt composition. Arabic input/RTL and paste do not establish
   marked-text IME correctness; these checks remain pending without an appropriate IME.
3. When explicitly approved, use VoiceOver to traverse explorer, file/search actions, editor and results;
   inspect labels, text, selection, focus order/restoration and perform an edit.
4. Scroll the large fixture, resize the window, move between display scales and
   type while background results arrive. Record failures and the actual environment.

Until these target-device checks are complete, input/accessibility scores remain
partial or unverified and production qualification remains incomplete. ADR-0004
records Mourad's accepted DVUI choice separately from these observations; successful
compilation, synthetic composition events and adapter selection do not pass them.
