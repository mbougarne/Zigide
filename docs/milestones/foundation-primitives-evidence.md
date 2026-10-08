# Foundation Primitives Evidence Addendum

Evidence for [ZIT-008 through ZIT-013](../../tickets/foundation-primitives.md), recorded on 2026-10-05. This supplements the dated [Milestone 0 snapshot](milestone-0-evidence-report.md); it does not declare the milestone exit-ready.

## Environment and scope

Local verification uses Zig `0.16.0` on macOS `27.0.1`, `arm64`, with an isolated checkout and Zig cache. The implementation adds no dependencies and keeps the accepted module import graph. Production time reads are isolated in the adapters module.

## Acceptance evidence

| Ticket | Evidence |
| --- | --- |
| ZIT-008 | Distinct operation, correlation and resource ID types, injected caller-owned deterministic generators with exhaustion errors, manual wall/monotonic clocks and a system clock adapter. `tests/fixtures/mixed_foundation_ids.zig` must fail compilation when assigning an operation ID to a correlation ID. Time tests use no sleeps or global mutation. |
| ZIT-009 | Inline atomic cancellation source with borrowed tokens, idempotent signaling, explicit observer joining/lifetime contract and cross-thread observation test. Request cleanup tests cover success, failure, cancellation and abandonment. |
| ZIT-010 | Typed synchronous scoped events with disposable ID handles. Behavioral tests cover ordering, repeated/copy disposal, removal before a handler runs, self-disposal, nested dispatch, addition during dispatch and emitter cleanup. Callback context is destroyed only after the outermost dispatch ends. |
| ZIT-011 | Context metadata preserves category, operation and typed operation/resource identities alongside ordinary Zig error unions. UI messages use fixed category text; logging tests retain the same context without raw payload/path fields. |
| ZIT-012 | Structured events contain timestamp, severity, subsystem, event name and correlation ID. Replaceable synchronous sink, deterministic capture, failure containment and debug opt-in are tested. A bounded schema excludes document contents, prompts, tokens, environment dumps and protocol payloads. |
| ZIT-013 | [Foundation ownership documentation](../../src/foundation/README.md) identifies allocators, borrowed lifetimes, cleanup and thread contracts. The testing allocator and exhaustive allocation-failure injection cover event registration and scoped request resources; disposal/cleanup tests assert exactly-once destruction. |

## Verification

- `zig build check --summary all`: 20 tests pass, plus the forbidden-import and mixed-ID compile-failure fixtures; formatting, repository hygiene, Markdown links and trace checks pass.
- `zig build check -Doptimize=ReleaseSafe --summary all`: the same acceptance suite passes with runtime safety in optimized code.
- `zig build --summary all` and `zig build run --summary all`: executable builds and exits successfully.
- `git diff --check`: passes.

The foundation and adapter roots are explicitly registered as test artifacts. Importing these modules from a smoke test alone does not run their test bodies.

Hosted exact-head CI will be checked after PR publication; this file records local evidence. Full headless service composition, real worker shutdown orchestration, protocol integration, persisted/global IDs, log storage/rotation and UI behavior remain with later tickets; none is claimed by this phase.
