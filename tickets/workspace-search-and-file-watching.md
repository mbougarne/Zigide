# Workspace Search and File Watching

- **Type:** Feature
- **Milestone:** 2 - Zig Work Loop
- **Goal:** Search the workspace on background workers and reconcile external file-tree changes safely.
- **Architecture:** [State and concurrency](../docs/architecture/02-system-architecture.md#state-and-concurrency), [Security boundaries](../docs/architecture/04-data-safety-and-operations.md#security-boundaries)

## ZIT-109: Implement Bounded Workspace Traversal

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-052, ZIT-100, ZIT-101
- **Description:** Traverse workspace files with path normalization, symlink policy, size limits, and configurable exclusions.
- **Acceptance criteria:**
  - [ ] Traversal avoids loops, paths outside policy, and unbounded directory accumulation.
  - [ ] Default exclusions and user exclusions are deterministic and tested.

## ZIT-110: Implement Filename Search

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-109
- **Description:** Match filenames and relative paths with bounded, cancellable result collection.
- **Acceptance criteria:**
  - [ ] Results are stable, ranked by documented simple rules, and open the correct resource.
  - [ ] Empty, cancelled, inaccessible, and result-limit states are distinguishable.

## ZIT-111: Implement Literal Workspace Text Search

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-064, ZIT-109
- **Description:** Search bounded text files for literal UTF-8 queries without requiring an index or regex engine.
- **Acceptance criteria:**
  - [ ] Binary, unreadable, invalid-UTF-8, oversized, and long-line files follow documented behavior.
  - [ ] Result ranges validate against the searched snapshot content.

## ZIT-112: Stream and Cancel Search Results

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-009, ZIT-057, ZIT-110, ZIT-111
- **Description:** Deliver bounded search batches with operation IDs and stop superseded or cancelled searches.
- **Acceptance criteria:**
  - [ ] Cancelled searches stop producing applicable results.
  - [ ] Search work and result delivery do not mutate workspace state from worker threads.

## ZIT-113: Implement Search Result Navigation

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-092, ZIT-110, ZIT-111, ZIT-112
- **Description:** Present filename/text results and navigate to validated resources and ranges.
- **Acceptance criteria:**
  - [ ] Deleted, changed, or invalid result locations fail safely when invoked.
  - [ ] Keyboard and accessibility labels identify file, line, and match context.

## ZIT-114: Implement the macOS File-Watch Adapter

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-052, ZIT-086
- **Description:** Observe workspace create, modify, rename, and delete activity through the selected macOS API.
- **Acceptance criteria:**
  - [ ] Adapter callbacks are marshalled to the application thread.
  - [ ] Watch setup, overflow, root removal, and shutdown failures are observable.

## ZIT-115: Reconcile Watch Events and Rescans

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-068, ZIT-100, ZIT-114
- **Description:** Coalesce duplicate/burst events, update explorer state, and trigger bounded rescans when event fidelity is lost.
- **Acceptance criteria:**
  - [ ] Final explorer and open-document external state matches disk after tested bursts.
  - [ ] Overflow and rename ambiguity use a documented rescan strategy.
