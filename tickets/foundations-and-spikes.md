# Foundations and Spikes

- **Type:** Epic
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Establish the product skeleton and retire the architecture's highest-risk assumptions before production feature work.
- **Architecture:** [Delivery roadmap](../docs/architecture/05-delivery-roadmap.md), [ADR-0001](../docs/architecture/decisions/0001-zig-first-modular-architecture.md), [ADR-0004](../docs/architecture/decisions/0004-ui-toolkit-selection.md)

## ZIT-001: Define Milestone 0 Exit Checklist

- **Status:** Done
- **Priority:** P0
- **Estimate:** 0.5-1 day
- **Dependencies:** Existing repository tooling
- **Description:** Turn every Milestone 0 exit condition into an evidence checklist with an owner ticket and exact verification command or artifact.
- **Acceptance criteria:**
  - [x] Every roadmap exit condition maps to at least one ticket in this epic.
  - [x] The checklist distinguishes automated checks, benchmarks, manual UI evidence, and ADR decisions.

## ZIT-002: Publish Milestone 0 Evidence Report

- **Status:** In Progress
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-007, ZIT-013, ZIT-019, ZIT-026, ZIT-033, ZIT-041
- **Description:** Consolidate exact tool versions, checks, measurements, failures, and resolved decisions into the Milestone 0 completion report.
- **Acceptance criteria:**
  - [ ] The report links all required test, benchmark, protocol, and UI evidence.
  - [x] Known limitations and unverified assumptions are explicit before Milestone 1 is declared started.

PR [#1](https://github.com/mbougarne/Zigide/pull/1) merged the initial evidence
snapshot on 2026-09-14. That report explicitly stated that Milestone 0 was not
exit-ready, and the same change deliberately moved ZIT-002 from Planned to
In Progress. The [historical report](https://github.com/mbougarne/Zigide/blob/e6628df2118694bdc8175c4eb8e8b6d492cf69f2/docs/milestones/milestone-0-evidence-report.md)
and [contemporaneous record](../agents/conversations/2026-09-14-10-29-35-e0bbc10c-b24c-46c9-84c7-f0194dc21507.md)
distinguish publishing that snapshot from completing its prerequisite-owned evidence.

The old report's missing implementation list is historical: module boundaries,
foundation services, headless lifecycle, protocol/ZLS and text-model evidence now
exist, and ADR-0004 accepts DVUI. The remaining ZIT-041 prerequisite evidence is
physical IME composition, observed VoiceOver use and the outstanding target-device
UI measurements described in [the spike acceptance record](ui-toolkit-spike.md#implementation-evidence-and-remaining-acceptance).
Final completion also requires consolidating that evidence, exact revisions/builds
and limitations into the final report. These requirements remain pending; a merged
initial report or successful build/CI does not supply the missing observations.
Milestone reports remain local under ignored `docs/milestones/`; none is restored
to tracking or relocated by this clarification.
