# Protocol framing and ZLS spike evidence

Evidence for [ZIT-020–026](../../tickets/protocol-framing-and-zls-spike.md), recorded
2026-10-08 on macOS arm64 with Zig 0.16.0. Baseline `f0cb2ec` includes merged PR #5
(ZIT-016–019) and PR #6. No unassigned prerequisite work was needed.

| Ticket | Evidence |
| --- | --- |
| ZIT-020 | Every two-way split of a combined UTF-8/empty-frame stream, small arbitrary fragments, supported extra headers, truncation and malformed-header tests. Errors are bounded and poison the connection. |
| ZIT-021 | Byte-counted encoder/decoder round trips; header and payload limits; overflowed/oversized advertised lengths fail before body allocation; actual oversized payloads fail before encoding. |
| ZIT-022 | Validated requests, notifications, results and errors; bounded 64-slot correlation; unknown, out-of-order, duplicate and late responses; cleanup on success/error, failed send abandonment and disconnect. |
| ZIT-023 | Borrowed cancellation tokens and monotonic deadlines; terminal results recheck both; cancellation and timeout remain distinct; cancellation notification encoding; no late result resurrection. |
| ZIT-024 | Real argv child emits 2,049 frames and 16 MiB stderr concurrently; bounded diagnostics; missing executable, truncated EOF, closed input, nonzero exit, deadline, injected termination denial and post-pipe-EOF process termination. |
| ZIT-025 | Official ZLS 0.16.0 completed initialize, initialized, shutdown and exit through the adapter with validated responses, exit 0 and zero pending requests. |
| ZIT-026 | 20,000 deterministic raw/mutated stream cases, seed `0x5a49542020026`; 4,096 combined response frames; every retained fixture chunk size; allocator failure injection and leak-detecting test allocator. |

## Executed checks

- Debug `zig build check --summary all`: 52 tests plus both negative compile fixtures pass; repository hygiene, links, trace validation and formatting pass before final records.
- Real `zig build zls-spike -Dzls=/absolute/path/to/zls --summary all`: passed with Zig 0.16.0 and ZLS 0.16.0. The fixture launches `zls --config-path zls.json --log-file zls.log --enable-stderr-logs` inside its random temporary Zig workspace. Zig is selected from the pinned build toolchain, not guessed from server configuration.
- ZLS archive: official `zls-aarch64-macos.tar.xz`, release `0.16.0`; SHA-256 `b93ec549f8558a7e85984a840e9276d274f1059b54ade4254296ef4982958359`.

ReleaseSafe checks, final record/schema validation, publication and exact-head CI
are reported in the task outcome after this evidence snapshot.

## Regressions and limits

Retained wire fixtures cover duplicate lengths, oversized lengths, truncated body
and repeated late responses. The process fixture retains the discovered EOF
regression (Zig 0.16 reports `EndOfStream`) and the process ownership regression
when output pipes close before process exit. The live server caught an empty
capabilities tuple serialized as an array; the fixture now sends an explicit JSON
object and validates a real initialize result.

The optional coverage-guided command `zig build integration-test --fuzz=10000`
failed inside the installed Zig 0.16.0 `compiler/test_runner.zig:566`: it passes a
`builtin.StackTrace` pointer to a function requiring `debug.StackTrace`. That
campaign did **not** run and is not counted as passed. The deterministic generated
suite and corpus replay passed. Finite testing cannot prove safety for every
possible stream; implementation bounds and ownership contracts complement it.

No production LSP document synchronization, language features, extension version
negotiation, descendant process supervision or UI acceptance is claimed. See
[protocol ownership and reproduction](../../src/adapters/protocol/README.md).
