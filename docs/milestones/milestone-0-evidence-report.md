# Milestone 0 Evidence Report

Evidence snapshot for [Milestone 0: Foundations and Spikes](../architecture/05-delivery-roadmap.md#milestone-0-foundations-and-spikes), published for [ZIT-002](../../tickets/foundations-and-spikes.md#zit-002-publish-milestone-0-evidence-report) on 2026-09-14. The report uses the evidence contract in the [Milestone 0 exit checklist](milestone-0-exit-checklist.md).

## Outcome

**Milestone 0 is not exit-ready.** The repository baseline and traceability tooling are verified, but product source modules, foundation services, headless composition, protocol framing, text-model, and UI-spike evidence have not been implemented or published. Milestone 1 must not be declared started from this report.

This is an honest evidence snapshot, not a completion claim. Each missing item remains linked to the ticket that owns its final evidence.

## Toolchain and Environment

| Item | Observed value | Evidence |
| --- | --- | --- |
| Target architecture | macOS `arm64` | `uname -m` |
| Operating system | macOS `26.6.2` | `sw_vers -productVersion` |
| Zig | `0.16.0` | `zig version`; `build.zig.zon` sets `minimum_zig_version = "0.16.0"` |
| Git | `2.50.1 (Apple Git-155)` | `git --version` |
| CI configuration | macOS runner runs `zig build check`; Ubuntu validates the trace schema | [.github/workflows/ci.yml](../../.github/workflows/ci.yml) |

The local toolchain matches the pinned repository version. The hosted CI jobs were not executed in this interaction; their acceptance remains external evidence.

## Verification Performed

| Command | Result | Scope and limitation |
| --- | --- | --- |
| `zig build` | Pass | Builds the current repository-check executable; no Zigide product executable exists yet |
| `zig build test` | Pass | Runs the current checker unit tests; product unit and integration test targets are not wired yet |
| `zig build check` | Pass | Runs formatting, repository hygiene, Markdown-link, trace-ledger, orphan-record, and checker tests |
| `git diff --check` | Pass | No whitespace errors in the current change set |

These passes establish repository health only. They do not satisfy the future product evidence owned by ZIT-006, ZIT-013, ZIT-019, ZIT-026, ZIT-033, or ZIT-041.

## Exit Conditions

| ID | Condition | Owner | Current state | Evidence or blocker |
| --- | --- | --- | --- | --- |
| E1 | Documented macOS arm64 build/test path with pinned Zig | [ZIT-006](../../tickets/application-module-layout.md#zit-006-add-product-unit-and-integration-test-targets) | Partial | Local baseline commands pass above. Product test targets, clean-clone verification, and hosted CI acceptance remain pending. |
| E2 | ADR-0004 accepted or replaced | [ZIT-041](../../tickets/ui-toolkit-spike.md#zit-041-score-candidates-and-resolve-adr-0004) | Blocked | [ADR-0004](../architecture/decisions/0004-ui-toolkit-selection.md) remains Proposed; no scored UI comparison has been published. |
| E3 | Protocol decoder handles split, combined, malformed, oversized, and cancelled messages | [ZIT-026](../../tickets/protocol-framing-and-zls-spike.md#zit-026-fuzz-and-stress-the-framing-prototype) | Blocked | No framing implementation, fuzz/stress suite, or retained regression fixtures exist yet. |

## Deliverables

| ID | Deliverable | Owner | Current state | Required evidence |
| --- | --- | --- | --- | --- |
| D1 | Zig build, module layout, formatter, test command, and CI | [ZIT-007](../../tickets/application-module-layout.md#zit-007-enforce-module-dependency-boundaries) | Partial | Repository tooling and CI configuration exist and pass locally; product module layout, product targets, and enforced dependency graph remain pending. |
| D2 | Pinned Zig toolchain and upgrade policy | [ZIT-001](../../tickets/foundations-and-spikes.md#zit-001-define-milestone-0-exit-checklist) | Verified baseline | `build.zig.zon`, README, delivery roadmap, and CI configuration document the `0.16.0` policy; hosted CI resolution remains unverified locally. |
| D3 | Headless application composition with logging, commands, and deterministic shutdown | [ZIT-019](../../tickets/headless-application-and-commands.md#zit-019-build-headless-port-test-doubles) | Not evidenced | Requires headless composition tests with substituted file, clock, process, and UI ports. |
| D4 | UI toolkit spike per ADR-0004 criteria | [ZIT-041](../../tickets/ui-toolkit-spike.md#zit-041-score-candidates-and-resolve-adr-0004) | Not evidenced | Requires spike code, screenshots, IME and accessibility observations, measurements, packaging results, and scored comparison. |
| D5 | Text-model benchmark and property-test harness | [ZIT-033](../../tickets/text-model-spike.md#zit-033-publish-text-model-recommendation) | Not evidenced | Requires property/equivalence tests, representative workloads, benchmark measurements, and a published storage recommendation. |
| D6 | ZLS process and framing spike | [ZIT-026](../../tickets/protocol-framing-and-zls-spike.md#zit-026-fuzz-and-stress-the-framing-prototype) | Not evidenced | Requires the ZIT-025 real-ZLS initialize/shutdown fixture plus framing fuzz/stress evidence and exact environment assumptions. |

## Decisions

| Decision | Status | Evidence |
| --- | --- | --- |
| Zig-first modular architecture | Accepted | [ADR-0001](../architecture/decisions/0001-zig-first-modular-architecture.md) |
| Out-of-process extensions | Accepted | [ADR-0002](../architecture/decisions/0002-out-of-process-extensions.md) |
| Open, versioned external protocols | Accepted | [ADR-0003](../architecture/decisions/0003-open-versioned-protocols.md) |
| UI toolkit selection by evidence | Proposed | [ADR-0004](../architecture/decisions/0004-ui-toolkit-selection.md); resolution is owned by ZIT-041 |

No accepted architectural decision was reversed by this report.

## Known Limitations and Unverified Assumptions

- The current checkout has no product source or product test targets; `zig build test` cannot yet verify application behavior.
- Hosted CI was not run from this local interaction, so macOS arm64 CI and Ubuntu JSON Schema acceptance remain unverified.
- No real ZLS process fixture, protocol decoder, text-model benchmark, UI spike, screenshots, IME test, or VoiceOver test has been published.
- No Milestone 0 performance measurements or failure reports exist yet. Absence of a report is not evidence that a spike passed.
- The report records current evidence only; later ticket work must append or supersede the relevant evidence without rewriting this snapshot.

## Milestone 1 Gate

Do not declare Milestone 1 started until E1, E2, and E3 are complete and D1 through D6 have the evidence required by the checklist. ZIT-002 documents the gate; it does not waive the dependencies listed in the ticket backlog.
