# Milestone 0 Exit Checklist

Evidence checklist for [Milestone 0: Foundations and Spikes](../architecture/05-delivery-roadmap.md#milestone-0-foundations-and-spikes), fulfilling [ZIT-001](../../tickets/foundations-and-spikes.md#zit-001-define-milestone-0-exit-checklist). Each row names the owning ticket and the exact verification command or artifact. [ZIT-002](../../tickets/foundations-and-spikes.md#zit-002-publish-milestone-0-evidence-report) consolidates the completed rows into the milestone evidence report.

Evidence kinds: **automated** (a command that must pass), **benchmark** (a measured report), **manual** (human-observed UI evidence), **decision** (an ADR outcome).

## Roadmap Exit Conditions

| # | Exit condition | Kind | Owner ticket | Verification |
| --- | --- | --- | --- | --- |
| E1 | One documented build/test path works on macOS arm64 with the pinned Zig version | automated | [ZIT-007](../../tickets/application-module-layout.md#zit-007-enforce-module-dependency-boundaries) | `zig build check` and `zig build test` pass locally and in the `CI` workflow on a clean clone, using the Zig version resolved from `minimum_zig_version` in `build.zig.zon`; the path is documented in `README.md` |
| E2 | ADR-0004 is accepted or replaced | decision | [ZIT-041](../../tickets/ui-toolkit-spike.md#zit-041-score-candidates-and-resolve-adr-0004) | `docs/architecture/decisions/0004-ui-toolkit-selection.md` status is `Accepted` or a superseding ADR exists, backed by the published scored comparison |
| E3 | Protocol decoder handles split, combined, malformed, oversized, and cancelled messages | automated | [ZIT-026](../../tickets/protocol-framing-and-zls-spike.md#zit-026-fuzz-and-stress-the-framing-prototype) | The framing fuzz/stress suite covering all five malformation classes passes under `zig build test` (exact step name defined by ZIT-026) |

## Roadmap Deliverables

| # | Deliverable | Kind | Owner | Verification |
| --- | --- | --- | --- | --- |
| D1 | Zig build, module layout, formatter, test command, and CI | automated | [Application module layout](../../tickets/application-module-layout.md) (ZIT-003 to ZIT-007) | `zig build check` (includes `zig fmt --check` and unit tests) passes; `.github/workflows/ci.yml` runs it on macOS arm64. Repository tooling already exists; the module layout tickets complete the product build graph |
| D2 | Pinned Zig toolchain and upgrade policy | automated | Complete (pre-backlog tooling) | `build.zig.zon` declares `minimum_zig_version = "0.16.0"`; CI resolves its toolchain from that field; policy documented in the delivery roadmap |
| D3 | Headless application composition with logging, commands, and deterministic shutdown | automated | [Headless application and commands](../../tickets/headless-application-and-commands.md) (exit: [ZIT-019](../../tickets/headless-application-and-commands.md#zit-019-build-headless-port-test-doubles)) | Headless composition tests run under `zig build test` with substituted file, clock, process, and UI ports (ADR-0001 validation) |
| D4 | UI toolkit spike per ADR-0004 criteria | manual + benchmark + decision | [UI toolkit spike](../../tickets/ui-toolkit-spike.md) (exit: ZIT-041) | Published spike code, screenshots, startup/memory measurements, IME and accessibility observations, and the scored comparison feeding E2 |
| D5 | Text-model benchmark and property-test harness | benchmark | [Text model spike](../../tickets/text-model-spike.md) (exit: [ZIT-033](../../tickets/text-model-spike.md#zit-033-publish-text-model-recommendation)) | Property tests pass under `zig build test`; the benchmark report for large-file and edit-heavy workloads backs the published storage recommendation |
| D6 | ZLS process and framing spike | automated | [Protocol framing and ZLS spike](../../tickets/protocol-framing-and-zls-spike.md) (exit: ZIT-026) | A real ZLS child process completes initialize/shutdown through the shared framing layer in an integration test; fuzz evidence per E3 |

## Status Tracking

A row is complete only when its verification exists and is referenced from the owning ticket. Do not mark rows here; completion lives in ticket statuses and the ZIT-002 report, keeping this checklist a stable map rather than a second status board.
