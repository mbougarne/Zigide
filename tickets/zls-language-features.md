# ZLS Language Features

- **Type:** Feature
- **Milestone:** 2 - Zig Work Loop
- **Goal:** Expose completion, hover, navigation, formatting, and symbols through application commands and validated edits.
- **Architecture:** [First release scope](../docs/architecture/01-vision-and-scope.md#first-release-scope), [State and concurrency](../docs/architecture/02-system-architecture.md#state-and-concurrency)

## ZIT-131: Register Capability-Aware Language Commands

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-016, ZIT-125
- **Description:** Register language commands only when negotiated capabilities and current document context permit them.
- **Acceptance criteria:**
  - [ ] Unsupported features are disabled with inspectable reasons.
  - [ ] Commands do not expose raw LSP types outside the adapter/application boundary.

## ZIT-132: Implement Completion

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-094, ZIT-126, ZIT-127, ZIT-131
- **Description:** Request, present, filter, and apply completion items through validated edit transactions.
- **Acceptance criteria:**
  - [ ] Stale versions and invalid edits are rejected before mutation.
  - [ ] Keyboard selection, cancellation, empty, loading, and error states are accessible.

## ZIT-133: Implement Hover

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-126, ZIT-127, ZIT-131
- **Description:** Request hover information and display bounded plain or safely rendered content near the relevant range.
- **Acceptance criteria:**
  - [ ] Superseded hover requests cancel and cannot replace newer content.
  - [ ] Untrusted markup cannot execute code or load remote content.

## ZIT-134: Implement Go to Definition

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-092, ZIT-126, ZIT-131
- **Description:** Resolve one or more definition locations and open validated workspace resources/ranges.
- **Acceptance criteria:**
  - [ ] Invalid or external locations follow documented trust/path behavior.
  - [ ] Multiple definitions are keyboard-selectable and labelled.

## ZIT-135: Implement Find References

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-113, ZIT-126, ZIT-131
- **Description:** Request references, present bounded results, and navigate only after resource/range validation.
- **Acceptance criteria:**
  - [ ] Cancellation and result limits are enforced.
  - [ ] Changed/deleted locations fail safely when opened.

## ZIT-136: Implement Document Formatting

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-059, ZIT-126, ZIT-127, ZIT-131
- **Description:** Validate and apply server formatting edits as one reversible transaction.
- **Acceptance criteria:**
  - [ ] Any invalid or stale edit rejects the complete batch.
  - [ ] Successful formatting is one undo step with preserved selection intent.

## ZIT-137: Implement Document and Workspace Symbols

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-103, ZIT-126, ZIT-131
- **Description:** Request symbols, display hierarchy or flat results, and navigate to validated locations.
- **Acceptance criteria:**
  - [ ] Large symbol sets are bounded and cancellable.
  - [ ] Keyboard and accessibility labels include symbol kind and location context.

## ZIT-138: Verify ZLS Feature Integration

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-132, ZIT-133, ZIT-134, ZIT-135, ZIT-136, ZIT-137
- **Description:** Run all language features against deterministic protocol fixtures and the recorded real ZLS/sample project.
- **Acceptance criteria:**
  - [ ] Success, unsupported, empty, malformed, cancelled, stale, and crash scenarios are covered.
  - [ ] Core result interactions pass keyboard and accessibility checks.
