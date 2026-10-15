# Production text follow-ups

## Coverage-guided Zig runner failure

The spike records a pinned Zig 0.16.0 fuzz-runner `builtin.StackTrace` versus
`debug.StackTrace` compiler failure. This work extends deterministic seeded
property and allocation-failure tests; it does not modify the toolchain or claim
a new coverage-guided campaign. Keep the compiler-runner repair separate from
ZIT-044–051, retain deterministic seeds, and requalify fuzz mode after a reviewed
pinned toolchain fix. No product data-correctness check is disabled.

## Qualification boundaries

Production text measurements exercise the headless domain on the recorded Mac.
They do not qualify the full editor, DVUI rendering/input, physical IME,
VoiceOver, file I/O, recovery, or a live provider. Those remain with their existing
tickets and the outstanding manual milestone checklist from PR #10. No extra
window, input-source, accessibility or power-setting changes are required here.

The ignored historical spike report and its numeric preliminary thresholds are
absent from the current checkout/history. Reused fixture/workload code is the
available provenance. The initial production checkpoint thresholds are explicit
in the text budget document and Zig summarizer; maintainer approval of those
thresholds remains separate from measured pass/fail evidence. Do not claim that
missing historic thresholds were recovered or previously approved.
