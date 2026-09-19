# Zigide review checks

Use this file as a relevance map, not a requirement to run every command. The workflow supplies a current check-run snapshot; report it accurately and do not execute repository code during review.

## Repository boundaries

- Follow `AGENTS.md`, `AGENTIC_RULES.md`, accepted ADRs, and the public `agents/` trace rules from the trusted base revision.
- Preserve the documented Zigide architecture, dependency direction, and milestone scope. Do not request unrelated abstraction or roadmap work.
- Treat build configuration, protocol/schema changes, public documentation, and trace-ledger integrity as compatibility surfaces.
- Keep findings source-grounded: confirm behavior against the repository's current Zig version and APIs instead of relying on memory from older Zig releases.

## Zig implementation

- Use the Zig version pinned in `build.zig.zon` and the repository build graph.
- The canonical local quality gate is `zig build check`; CI runs it on macOS.
- Review explicit allocation ownership, `defer`/`errdefer` cleanup, error unions, optional handling, slice and pointer lifetimes, mutation/aliasing, integer conversions, bounds, process lifecycle, and platform assumptions where affected.
- For subprocess, protocol, or editor integration changes, examine partial reads/writes, framing, malformed input, shutdown, cancellation, deadlock, resource cleanup, and deterministic error reporting.

## Documentation and traceability

- CI separately validates tracked JSON records against their schemas.
- The checker enforces repository hygiene, Markdown links, trace-ledger rules, and Zig formatting in addition to tests/builds.
- Verify that required conversation, research, command, and history entries remain internally consistent and do not leak secrets or unsupported claims.

## Platform evidence

- The project targets macOS/arm64 behavior. Linux schema validation or static inspection is not macOS runtime acceptance.
- State clearly when GUI, process, filesystem, protocol-peer, or macOS-specific behavior lacks runtime evidence.
- A passing build or unit suite does not establish live editor integration or end-to-end protocol behavior.

## Evidence standard

- A failing command or check is not itself a code defect; connect it to an introduced behavior and location.
- Do not report formatting or ledger errors as product defects unless their concrete impact and introduced line meet the finding criteria.
- Never recommend weakening a checker, schema, test, safety rule, or toolchain pin solely to make the change pass.
