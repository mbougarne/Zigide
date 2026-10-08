# Protocol framing and process spike

Private adapter prototypes for [ZIT-020–026](../../../tickets/protocol-framing-and-zls-spike.md).
The domain/application import graph is unchanged. This is not the production LSP
client, extension protocol, or task/process service.

## Ownership and limits

`framing.Decoder.feed` consumes arbitrary chunks and returns at most one owned
payload plus its consumed count. Feed the remainder again, free returned payloads,
and call `finish` on EOF. `deinit` frees partial input. Errors poison the decoder:
discard the connection instead of guessing where framing resumes. Header names
are case insensitive; ASCII extra headers are accepted. Duplicate lengths,
nondecimal/overflowed lengths, malformed lines and truncation have distinct errors.
Defaults are 8 KiB headers and 1 MiB payloads. Advertised size is checked before
body allocation; encoding checks actual UTF-8 byte length before allocation.

`rpc.decode` owns its parsed JSON until `Message.deinit`. It validates the envelope
before dispatch. Incoming string IDs remain in the parsed message; the correlator
only matches its own positive numeric IDs, bounded to the interoperable 53-bit
integer range. Its 64 pending slots borrow cancellation sources until completion,
`abandon`, `poll`, or `disconnect`; no per-request allocation is retained. Sources
must outlive their pending requests. IDs are never reused. Unknown, duplicate,
and late responses cannot apply results. Explicit cancellation wins if cancellation
and deadline are simultaneously observed. `poll` returns distinct cancellation
or timeout outcomes; pass each returned ID to `cancelPayload` and send that JSON
through the transport to propagate `$/cancelRequest`. A send failure must abandon
the request or disconnect the correlator. Correlators are single-owner objects.

`transport.run` starts argv directly, with no shell. Its conversation owns
stdin/stdout; stderr drains concurrently into a bounded 4 KiB diagnostic prefix.
Returned frames must be freed. Conversations must perform cancellable I/O and
must drain stdout while interacting; they must not run unbounded CPU work or send
an unbounded batch without reading responses. A deadline joins I/O workers,
force-terminates the owned process and reaps it. Errors include spawn, framing,
closed input, pipe I/O, deadline and explicit termination failures; nonzero exits
are returned in `Result.term`. Diagnostics are also available on failure.

The first-release process spike uses POSIX signal/wait operations. Its nonblocking
reap loop preserves process ownership during cancellation: Zig 0.16 `Child.wait`
cleans up the child handle even when cancelled, preventing later termination.
Tests retain a child that closes both output pipes and continues running to guard
this case. This prototype supervises the direct child only, not a descendant tree.

## Reproduce

```sh
zig build check --summary all
zig build check -Doptimize=ReleaseSafe --summary all
zig build zls-spike -Dzls=/absolute/path/to/zls --summary all
```

The opt-in live target requires ZLS 0.16.0. It records exact Zig/ZLS versions,
workspace and command assumptions, checks capabilities and shutdown responses,
and requires exit 0 and an empty pending table. It creates a random temporary
workspace containing `main.zig`, `build.zig`, and a local `zls.json` pointing to
the build's Zig executable. Success removes that workspace; failure retains it
and prints bounded stderr for diagnosis. It opens no sockets. CI separately runs
the real target using a checksum-pinned official ZLS release.

`zig build test` always runs seeded fuzz/stress, retained wire fixtures and
allocation-failure tests without requiring an installed server. The optional
`zig build integration-test --fuzz=10000` entry invokes Zig's coverage-guided
runner. On the tested Zig 0.16.0 installation that runner fails to compile in
`compiler/test_runner.zig` due to incompatible StackTrace types; a normal test
run of its corpus is not a successful coverage-guided campaign. See the
[evidence report](../../../docs/milestones/protocol-framing-zls-evidence.md).
