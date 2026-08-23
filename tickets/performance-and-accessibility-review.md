# Performance and Accessibility Review

- **Type:** Feature
- **Milestone:** 4 - Public Preview
- **Goal:** Measure release budgets and complete structured keyboard, IME, scaling, focus, and VoiceOver review.
- **Architecture:** [Verification strategy](../docs/architecture/04-data-safety-and-operations.md#verification-strategy), [Quality gates](../docs/architecture/01-vision-and-scope.md#quality-gates)

## ZIT-203: Freeze Preview Benchmark Fixtures and Budgets

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-051, ZIT-099, ZIT-189
- **Description:** Freeze target hardware/OS conditions, fixtures, commands, repetitions, metrics, and blocking budgets for the candidate.
- **Acceptance criteria:**
  - [ ] Every measured budget has a repeatable command or documented manual protocol.
  - [ ] Budget changes from earlier milestones include evidence and approval.

## ZIT-204: Measure Startup and Memory

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-193, ZIT-203
- **Description:** Measure cold/warm startup, idle memory, workspace-open memory, and shutdown on the target Mac.
- **Acceptance criteria:**
  - [ ] Results include distributions or repeated samples, not one best run.
  - [ ] Regressions against UI-spike baselines are explained.

## ZIT-205: Measure File, Edit, and Scroll Performance

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-051, ZIT-099, ZIT-203
- **Description:** Measure large-file open, sustained edits, lookup, rendering, scrolling, and memory growth.
- **Acceptance criteria:**
  - [ ] Critical latency or memory budget misses block preview or receive explicit accepted exceptions.
  - [ ] Fixtures include long lines, mixed-width text, and realistic edit distributions.

## ZIT-206: Measure Search, Task, and Language Operations

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-108, ZIT-203
- **Description:** Measure workspace search, watcher reconciliation, build output, ZLS startup, and representative language requests while editing.
- **Acceptance criteria:**
  - [ ] Background operations do not exceed input-responsiveness budgets.
  - [ ] Measurements include cancellation and failure recovery costs.

## ZIT-207: Review Keyboard Navigation and Focus

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-106, ZIT-202
- **Description:** Complete all core workflows without a mouse and inspect visible focus, order, traps, and restoration.
- **Acceptance criteria:**
  - [ ] Every core action is keyboard reachable with coherent focus.
  - [ ] Blocking focus defects are fixed before preview.

## ZIT-208: Review VoiceOver Behavior

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-098, ZIT-106, ZIT-142, ZIT-202
- **Description:** Verify core regions, editor text/selection, problems, command results, status, and actionable errors with VoiceOver.
- **Acceptance criteria:**
  - [ ] Critical information is named, ordered, and operable without visual-only cues.
  - [ ] Accepted limitations are public and linked to follow-up tickets.

## ZIT-209: Review IME, Scaling, and Publish Results

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-097, ZIT-203, ZIT-204, ZIT-205, ZIT-206, ZIT-207, ZIT-208
- **Description:** Reverify IME composition, font fallback, scaling, layout, and consolidate performance/accessibility evidence.
- **Acceptance criteria:**
  - [ ] Input and scale changes preserve content, selection, and non-overlapping layout.
  - [ ] Report names hardware, OS, build, fixtures, failures, exceptions, and raw summarized results.
