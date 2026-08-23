# Production Text Model

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Implement a storage-independent, versioned text model using the structure selected by the spike.
- **Architecture:** [Text model](../docs/architecture/02-system-architecture.md#text-model)

## ZIT-044: Implement Production Text Storage

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-033
- **Description:** Implement the selected original/add buffer, piece tree, rope, or other approved production storage with explicit ownership.
- **Acceptance criteria:**
  - [ ] Insert, delete, replace, read, and deinit behavior matches the approved design.
  - [ ] Success and allocation-failure paths leak no memory.

## ZIT-045: Implement Positions and Ranges

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-044
- **Description:** Define zero-based offsets, positions, normalized ranges, comparison, and validation independent of UI or LSP types.
- **Acceptance criteria:**
  - [ ] Invalid and multibyte-splitting positions fail before access or mutation.
  - [ ] Protocol conversions remain outside the text module.

## ZIT-046: Implement Atomic Edit Batches and Versions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-045
- **Description:** Validate and apply all-or-nothing edit batches and increment document versions only after successful mutation.
- **Acceptance criteria:**
  - [ ] Invalid or overlapping batches leave content and version unchanged.
  - [ ] Valid batches produce deterministic content and one version transition.

## ZIT-047: Implement Stable Text Snapshots

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-044, ZIT-046
- **Description:** Provide immutable snapshots suitable for background work with a documented lifetime and allocation policy.
- **Acceptance criteria:**
  - [ ] A snapshot remains stable after later document edits.
  - [ ] Snapshot release cannot invalidate active document storage.

## ZIT-048: Implement the Production Line Index

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-045, ZIT-046
- **Description:** Maintain line starts and bounded offset/position lookup across edit batches.
- **Acceptance criteria:**
  - [ ] Lookups match reference behavior for empty, long-line, mixed-ending, and UTF-8 fixtures.
  - [ ] Index updates remain consistent after randomized edits.

## ZIT-049: Preserve Encoding and Line-Ending Metadata

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-046
- **Description:** Track decoding status, line-ending form, and final-newline state without silently normalizing user data.
- **Acceptance criteria:**
  - [ ] LF, CRLF, mixed endings, and final-newline absence round-trip through model metadata.
  - [ ] Invalid UTF-8 policy prevents silent replacement or loss.

## ZIT-050: Property-Test the Production Text Model

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-046, ZIT-047, ZIT-048, ZIT-049
- **Description:** Compare generated production operations with the reference model and retain reproducible regression seeds.
- **Acceptance criteria:**
  - [ ] Random edit, snapshot, and lookup sequences remain equivalent to the reference model.
  - [ ] Tests cover allocation failure and report no leaks.

## ZIT-051: Verify Production Text Budgets

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-050
- **Description:** Rerun approved workloads and verify or revise large-file, sustained-edit, lookup, and memory budgets.
- **Acceptance criteria:**
  - [ ] Results use release-like build settings and documented hardware/fixtures.
  - [ ] Any missed budget has an accepted reason and follow-up before milestone exit.
