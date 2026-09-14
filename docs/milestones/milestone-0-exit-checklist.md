# Milestone 0 Exit Checklist

Evidence checklist for [Milestone 0: Foundations and Spikes](../architecture/05-delivery-roadmap.md#milestone-0-foundations-and-spikes), fulfilling [ZIT-001](../../tickets/foundations-and-spikes.md#zit-001-define-milestone-0-exit-checklist). Each row names the ticket responsible for producing the final evidence and the exact verification command or artifact. [ZIT-002](../../tickets/foundations-and-spikes.md#zit-002-publish-milestone-0-evidence-report) consolidates the completed rows into the milestone evidence report.

Evidence kinds: **automated** (a command that must pass), **benchmark** (a measured report), **manual** (human-observed UI evidence), **decision** (an ADR outcome).

## Roadmap Exit Conditions

| # | Exit condition | Kind | Owner ticket | Verification |
| --- | --- | --- | --- | --- |
| E1 | One documented build/test path works on macOS arm64 with the pinned Zig version | automated | [ZIT-006](../../tickets/application-module-layout.md#zit-006-add-product-unit-and-integration-test-targets) | On a clean clone, `zig build`, `zig build test`, and `zig build check` pass locally with the version resolved from `minimum_zig_version` in `build.zig.zon`; the same `zig build check` command passes in `.github/workflows/ci.yml`, and the path is documented in `README.md` |
| E2 | ADR-0004 is accepted or replaced | decision | [ZIT-041](../../tickets/ui-toolkit-spike.md#zit-041-score-candidates-and-resolve-adr-0004) | `docs/architecture/decisions/0004-ui-toolkit-selection.md` status is `Accepted` or a superseding ADR exists, backed by the published scored comparison |
| E3 | Protocol decoder handles split, combined, malformed, oversized, and cancelled messages | automated | [ZIT-026](../../tickets/protocol-framing-and-zls-spike.md#zit-026-fuzz-and-stress-the-framing-prototype) | `zig build test` passes the ZIT-026 framing fuzz/stress suite, with retained regression fixtures covering split, combined, malformed, oversized, and cancelled messages |

## Roadmap Deliverables

| # | Deliverable | Kind | Owner ticket | Verification |
| --- | --- | --- | --- | --- |
| D1 | Zig build, module layout, formatter, test command, and CI | automated | [ZIT-007](../../tickets/application-module-layout.md#zit-007-enforce-module-dependency-boundaries) (with ZIT-003 to ZIT-006) | `zig build check` passes with formatter, repository, and product-test checks; `.github/workflows/ci.yml` runs the same command on macOS arm64; the enforced graph matches the documented module boundaries |
| D2 | Pinned Zig toolchain and upgrade policy | automated | [ZIT-001](../../tickets/foundations-and-spikes.md#zit-001-define-milestone-0-exit-checklist) (baseline evidence captured here) | `build.zig.zon` declares `minimum_zig_version = "0.16.0"`; `.github/workflows/ci.yml` resolves the toolchain from that field; the deliberate-upgrade policy is documented in the delivery roadmap |
| D3 | Headless application composition with logging, commands, and deterministic shutdown | automated | [ZIT-019](../../tickets/headless-application-and-commands.md#zit-019-build-headless-port-test-doubles) (with ZIT-014 to ZIT-018) | `zig build test` passes headless composition tests with substituted file, clock, process, and UI ports, demonstrating the ADR-0001 validation requirement |
| D4 | UI toolkit spike per ADR-0004 criteria | manual + benchmark + decision | [ZIT-041](../../tickets/ui-toolkit-spike.md#zit-041-score-candidates-and-resolve-adr-0004) (with ZIT-034 to ZIT-040) | ZIT-041 publishes the scored comparison and links the spike code, screenshots, startup/memory measurements, IME observations, accessibility observations, versions, licenses, and packaging results |
| D5 | Text-model benchmark and property-test harness | benchmark | [ZIT-033](../../tickets/text-model-spike.md#zit-033-publish-text-model-recommendation) (with ZIT-027 to ZIT-032) | `zig build test` passes the property/equivalence suite; ZIT-033 publishes the benchmark report with target hardware, build mode, workloads, iterations, latency context, memory results, and the storage recommendation |
| D6 | ZLS process and framing spike | automated | [ZIT-026](../../tickets/protocol-framing-and-zls-spike.md#zit-026-fuzz-and-stress-the-framing-prototype) (with ZIT-020 to ZIT-025) | `zig build test` passes the framing suite and the ZIT-025 integration fixture completes initialize, initialized, shutdown, and process exit with a real recorded ZLS version; the fixture records exact Zig, ZLS, workspace, and command assumptions |

## Status Tracking

A row is complete only when its verification exists and is referenced from the owner ticket or its published evidence artifact. “With” tickets are prerequisites that contribute evidence but do not own the final exit decision. D2 is a baseline repository deliverable with no separate implementation ticket; ZIT-001 records its evidence so it remains traceable. Do not mark rows here; completion lives in ticket statuses and the ZIT-002 report, keeping this checklist a stable map rather than a second status board.
