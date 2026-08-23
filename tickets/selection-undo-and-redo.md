# Selection, Undo, and Redo

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Provide validated selections and reversible edit transactions independent of input devices.
- **Architecture:** [Text-model invariants](../docs/architecture/02-system-architecture.md#text-model), [Command flow](../docs/architecture/02-system-architecture.md#command-flow)

## ZIT-058: Implement Selection State

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-045, ZIT-048
- **Description:** Represent anchor, active position, direction, and normalized selected range.
- **Acceptance criteria:**
  - [ ] Empty, forward, and reverse selections validate against the current document version.
  - [ ] Edits transform or replace selection state deterministically.

## ZIT-059: Define Edit Transactions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-046, ZIT-058
- **Description:** Group edits with before/after selections and command metadata into reversible transactions.
- **Acceptance criteria:**
  - [ ] A transaction either commits all edits and selection state or none.
  - [ ] Non-input commands can create the same transaction form.

## ZIT-060: Implement Undo

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-059
- **Description:** Reverse committed transactions in strict history order and restore prior selections.
- **Acceptance criteria:**
  - [ ] Undo restores exact content, metadata, and selection for each transaction.
  - [ ] Empty-history undo is safe and observable.

## ZIT-061: Implement Redo and Branching

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-060
- **Description:** Reapply undone transactions and define redo-history behavior after a new edit branch.
- **Acceptance criteria:**
  - [ ] Redo reproduces the original post-transaction state.
  - [ ] New edits after undo follow the documented branch policy.

## ZIT-062: Implement Typing Coalescence Rules

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-059, ZIT-061
- **Description:** Coalesce compatible typing/deletion actions while preserving explicit command and focus boundaries.
- **Acceptance criteria:**
  - [ ] Coalescence rules are deterministic and covered by timing-independent tests.
  - [ ] Paste, formatting, cursor jumps, and explicit boundaries remain separate transactions.

## ZIT-063: Bound and Property-Test Edit History

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-060, ZIT-061, ZIT-062
- **Description:** Enforce a documented memory policy and property-test random edit/undo/redo sequences.
- **Acceptance criteria:**
  - [ ] Round trips return to initial content and release discarded history.
  - [ ] Limit eviction is deterministic and never corrupts remaining history.
