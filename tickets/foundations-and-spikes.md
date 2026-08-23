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
- **Evidence:** [Milestone 0 exit checklist](../docs/milestones/milestone-0-exit-checklist.md)

## ZIT-002: Publish Milestone 0 Evidence Report

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-007, ZIT-013, ZIT-019, ZIT-026, ZIT-033, ZIT-041
- **Description:** Consolidate exact tool versions, checks, measurements, failures, and resolved decisions into the Milestone 0 completion report.
- **Acceptance criteria:**
  - [ ] The report links all required test, benchmark, protocol, and UI evidence.
  - [ ] Known limitations and unverified assumptions are explicit before Milestone 1 is declared started.
