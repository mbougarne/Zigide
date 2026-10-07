# Command validation and headless lifecycle evidence

Evidence for [ZIT-016 through ZIT-019](../../tickets/headless-application-and-commands.md),
recorded on 2026-10-07. Prerequisites ZIT-014/015 merged in PR #4 at `5465aef`.
This extends the [earlier composition evidence](headless-application-commands-evidence.md)
and satisfies the headless substitution exercise in ADR-0001 and milestone D3.
The other milestone exit gates remain separate work.

| Ticket | Observable evidence |
| --- | --- |
| ZIT-016 | Tagged arguments, value validation, enablement, cancellation and dispatch errors; rejected inputs do not invoke the handler. Callback-triggered cancellation and shutdown are rechecked. |
| ZIT-017 | Generation identities, idempotent disposal, stale-handle rejection, callback pins, heap-context disposal, and registration growth during dispatch. Application-thread lifecycle requests cannot release live handler context. |
| ZIT-018 | Dependency-ordered startup; persist/cancel/stop/flush/release phases; reverse stop/release; partial-start rollback; retained deadline; rejected commands during shutdown; reentrant Busy retry; one-time cleanup despite errors and deadline expiry. |
| ZIT-019 | A typed command composes separate file/storage stores, manual time, fake process and queued UI ports. Tests inject success, missing resources, permission/unavailability errors, delay, cancellation, stale process IDs and allocation failure without real OS effects. |

See [ownership and lifecycle contracts](../../src/application/README.md).
The accepted module import graph remains unchanged; no dependencies were added.
The integration test root imports the existing commands and ports modules to
exercise them together. Test caches and installation prefixes are task-specific;
there are no network listeners or containers.

## Local verification

Zig 0.16.0 on native macOS arm64:

- Debug `zig build check --summary all`: 41 tests and both negative compile fixtures pass.
- ReleaseSafe `zig build check -Doptimize=ReleaseSafe --summary all`: the same suite passes.
- Formatting, repository hygiene, Markdown links and trace checks pass in both configurations before this evidence and final trace records are added.
- Exhaustive allocation-failure tests cover registry operations, port doubles, and partial startup.
- The real executable starts and shuts down in an empty temporary workspace and environment.

Final document/schema checks, publication and exact-head hosted CI follow this
local evidence snapshot and are reported in the task conversation.

## Boundaries

Deadlines are cooperative: future process/worker adapters must bound waiting and
force cleanup before release. The application owner cannot preempt arbitrary
synchronous callbacks. Production file safety, persistence, worker/process
supervision, GUI interaction, live ZLS/extensions, packaging/signing and release
acceptance remain outside this batch. The doubles validate substitution and
orchestration, not those future platform implementations. Draft PRs skip the
existing automated review workflow; a skip is not a completed review.
