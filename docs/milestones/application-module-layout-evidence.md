# Application Module Layout Evidence Addendum

Evidence update for [ZIT-003 through ZIT-007](../../tickets/application-module-layout.md), recorded on 2026-09-20. This addendum supplements the dated [Milestone 0 evidence snapshot](milestone-0-evidence-report.md) without rewriting it.

## Environment

| Item | Observed value |
| --- | --- |
| Platform | macOS `arm64`, version `27.0` |
| Zig | `0.16.0`, matching `build.zig.zon` |

## Ticket Evidence

| Ticket | Outcome | Evidence |
| --- | --- | --- |
| ZIT-003 | Product and test responsibility directories exist without speculative product APIs. | `src/{foundation,text,workspace,commands,application,ports,adapters,ui,composition}` and `tests/`; each module root documents its boundary and exports no placeholder API. |
| ZIT-004 | Private Zig modules are wired with explicit direct imports. | `build.zig` declares the graph; [System Architecture](../architecture/02-system-architecture.md#source-boundaries) documents the same graph. Each module root references only its declared imports. |
| ZIT-005 | `zig build` produces `zig-out/bin/zigide`; the minimal composition root exits without filesystem, network, task, or extension actions. | `src/composition/main.zig`; standalone `zig build` and `zig build run`. |
| ZIT-006 | Unit and integration targets run separately and in `zig build check`. | `tests/unit.zig` compiles the product module roots. `tests/integration.zig` launches the executable with an empty environment from an isolated temporary workspace and verifies zero exit status, empty output, and no workspace files. |
| ZIT-007 | A deliberately forbidden `foundation -> ui` import is rejected by the controlled compile test. | `tests/fixtures/forbidden_domain_ui_import.zig`; the fixture uses the `foundation` import allowlist. A known-bad mutation adding `ui` to that allowlist caused `zig build test` to fail because the expected “no module named ui” diagnostic changed. The mutation was reverted. |

## Verification

The following local commands passed against the restored, approved graph:

- `zig build`
- `zig build run`
- `zig build unit-test`
- `zig build integration-test`
- `zig build test`
- `zig build check`
- `git diff --check`
- `jq empty agents/history.json`

Hosted CI was not run. These results establish the local build graph and its tests on macOS arm64; they do not complete other Milestone 0 work. Headless services, foundation behavior, protocol/ZLS, text-model, and UI-spike evidence remain owned by their respective tickets, and Milestone 0 is not exit-ready.
