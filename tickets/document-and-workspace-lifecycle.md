# Document and Workspace Lifecycle

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Model one local workspace, resource identities, open documents, dirty state, and safe lifecycle transitions.
- **Architecture:** [Source boundaries](../docs/architecture/02-system-architecture.md#source-boundaries), [State and concurrency](../docs/architecture/02-system-architecture.md#state-and-concurrency)

## ZIT-052: Define Local Resource Identity

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-019
- **Description:** Define normalized resource paths, equality, case behavior, and symlink policy for the macOS target.
- **Acceptance criteria:**
  - [ ] Equivalent paths resolve to one documented identity.
  - [ ] Workspace-boundary and symlink cases are covered by tests.

## ZIT-053: Implement Single-Folder Workspace Open and Close

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-052
- **Description:** Create and dispose one local folder workspace without native-dialog dependencies in domain code.
- **Acceptance criteria:**
  - [ ] Missing, unreadable, and non-directory roots return contextual errors.
  - [ ] Closing releases workspace-scoped state and subscriptions.

## ZIT-054: Implement the Open-Document Registry

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-044, ZIT-052, ZIT-053
- **Description:** Track multiple open text documents without duplicating normalized resources.
- **Acceptance criteria:**
  - [ ] Reopening the same resource returns existing document state.
  - [ ] Registry ownership and document deinitialization are deterministic.

## ZIT-055: Track Active and Dirty Document State

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-046, ZIT-054
- **Description:** Track active document and whether each document diverges from its last acknowledged save state.
- **Acceptance criteria:**
  - [ ] Dirty state follows edit, undo, save acknowledgement, and external-change transitions.
  - [ ] Active-document changes emit typed events once per transition.

## ZIT-056: Implement Dirty-Document Close Decisions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-055
- **Description:** Request save, discard, or cancel decisions through a UI-neutral contract before close, workspace switch, or shutdown.
- **Acceptance criteria:**
  - [ ] No dirty document closes silently.
  - [ ] Cancel preserves workspace and document state unchanged.

## ZIT-057: Reject Stale Workspace and Document Results

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-008, ZIT-047, ZIT-054
- **Description:** Attach operation and document/workspace versions to background results and discard stale outcomes on the application thread.
- **Acceptance criteria:**
  - [ ] Results for closed resources or older versions cannot mutate current state.
  - [ ] Tests cover close, reopen, workspace switch, cancellation, and out-of-order completion.
