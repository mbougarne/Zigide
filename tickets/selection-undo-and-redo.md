# Selection, Undo, and Redo

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Provide validated selections and reversible edit transactions independent of input devices.
- **Architecture:** [Text-model invariants](../docs/architecture/02-system-architecture.md#text-model), [Command flow](../docs/architecture/02-system-architecture.md#command-flow)

## ZIT-058: Implement Selection State

- **Status:** Done
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-045, ZIT-048
- **Description:** Represent anchor, active position, direction, and normalized selected range.
- **Acceptance criteria:**
  - [x] Empty, forward, and reverse selections validate against the current document version.
  - [x] Edits transform or replace selection state deterministically.

## ZIT-059: Define Edit Transactions

- **Status:** Done
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-046, ZIT-058
- **Description:** Group edits with before/after selections and command metadata into reversible transactions.
- **Acceptance criteria:**
  - [x] A transaction either commits all edits and selection state or none.
  - [x] Non-input commands can create the same transaction form.

## ZIT-060: Implement Undo

- **Status:** Done
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-059
- **Description:** Reverse committed transactions in strict history order and restore prior selections.
- **Acceptance criteria:**
  - [x] Undo restores exact content, metadata, and selection for each transaction.
  - [x] Empty-history undo is safe and observable.

## ZIT-061: Implement Redo and Branching

- **Status:** Done
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-060
- **Description:** Reapply undone transactions and define redo-history behavior after a new edit branch.
- **Acceptance criteria:**
  - [x] Redo reproduces the original post-transaction state.
  - [x] New edits after undo follow the documented branch policy.

## ZIT-062: Implement Typing Coalescence Rules

- **Status:** Done
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-059, ZIT-061
- **Description:** Coalesce compatible typing/deletion actions while preserving explicit command and focus boundaries.
- **Acceptance criteria:**
  - [x] Coalescence rules are deterministic and covered by timing-independent tests.
  - [x] Paste, formatting, cursor jumps, and explicit boundaries remain separate transactions.

## ZIT-063: Bound and Property-Test Edit History

- **Status:** Done
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-060, ZIT-061, ZIT-062
- **Description:** Enforce a documented memory policy and property-test random edit/undo/redo sequences.
- **Acceptance criteria:**
  - [x] Round trips return to initial content and release discarded history.
  - [x] Limit eviction is deterministic and never corrupts remaining history.

## Implemented contract

[Selection and history](../src/text/HISTORY.md) defines byte/version validation,
atomic prepared transactions, owned inverse edits, selection restoration, branch
discard, deterministic grouping and retained memory limits. Workspace integration
preserves save checkpoints, dirty state, focus boundaries and stale-result guards.
Focused cases cover exact metadata, allocation rollback, eviction and compaction;
16 fixed seeds each exercise 256 mixed history operations and final round trips.
`history-test`, `workspace-test` and the normal `check` graph include this coverage.
Physical keyboard shortcuts and DVUI input wiring remain with the UI feature scope.
