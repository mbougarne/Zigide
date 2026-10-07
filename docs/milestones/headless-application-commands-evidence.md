# Headless Application and Commands Evidence

Evidence for [ZIT-014 and ZIT-015](../../tickets/headless-application-and-commands.md), recorded on 2026-10-06. This supplements the dated [Milestone 0 snapshot](milestone-0-evidence-report.md); D3 remains incomplete until the later headless application tickets deliver their evidence.

## Scope and acceptance

| Ticket | Evidence |
| --- | --- |
| ZIT-014 | `application.Context` constructs services from explicit borrowed clock/logging ports. Only the executable root chooses the system clock and discard sink. Headless integration supplies a manual clock and capture/failure sink, invokes a resolved service handler, checks timestamps and failures, and proves registries are isolated and borrowed dependencies survive cleanup. |
| ZIT-015 | UI-independent registry copies namespaced IDs and resolves borrowed handlers by value. Tests cover every permutation of three registrations, exact case-sensitive lookup, explicit duplicate/unknown errors, malformed IDs, ID-buffer mutation, map growth, and exhaustive allocation failures. |

See the [application ownership and command contract](../../src/application/README.md). The existing module import graph is unchanged. There are no new dependencies, network listeners, persistent settings, child services, or platform operations in reusable application/command code.

## Verification

Local environment: Zig `0.16.0`, macOS `27.0.1`, arm64. Builds use an isolated checkout and task-specific Zig cache.

- `zig build check --summary all`: 27 tests and both negative compilation fixtures pass; repository hygiene, Markdown links, trace checks, and formatting pass (before adding this evidence file and final trace records).
- `zig build check -Doptimize=ReleaseSafe --summary all`: 27 tests and both negative compilation fixtures pass with the same repository checks. An initial missing evidence-link target was corrected before this passing run.
- `zig build --summary all` and `zig build run --summary all`: pass; the executable exits successfully.
- `npx -y ajv-cli@5.0.0 validate --spec=draft2020 -s agents/history.schema.json -d agents/history.json`: passes before appending the final trace entry.
- `git diff --check`: passes.

Final trace/schema revalidation and exact-head hosted checks follow publication preparation; this file records observed local results.

## Limits

This batch implements only ZIT-014 and ZIT-015. Typed command arguments and preconditions, registration disposal, ordered/idempotent shutdown, and reusable file/storage/process/UI test doubles remain ZIT-016 through ZIT-019. Clock/logging are the only currently consumed external ports; the full ADR-0001 substitution exercise is not claimed complete.

The executable is checked on the native Mac without a window, filesystem writes, or output. GUI/device interaction, live ZLS/extensions, signing, packaging, deployment, and production acceptance are not implemented or run in this scope. No dedicated repository security scanner is configured; invalid-input, ownership/allocation-failure tests and a changed-content privacy/secret review provide the applicable local security checks. Automated Anthropic review excludes draft PRs by its existing workflow condition.
