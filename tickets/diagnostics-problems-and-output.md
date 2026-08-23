# Diagnostics, Problems, and Output

- **Type:** Feature
- **Milestone:** 2 - Zig Work Loop
- **Goal:** Store versioned diagnostics and bounded output, then expose safe Problems and Output views.
- **Architecture:** [Observability](../docs/architecture/04-data-safety-and-operations.md#observability), [Security boundaries](../docs/architecture/04-data-safety-and-operations.md#security-boundaries)

## ZIT-139: Implement the Versioned Diagnostic Model

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-045, ZIT-052, ZIT-057
- **Description:** Store owner, resource, version, severity, code, source, message, and validated range in UI-independent diagnostic sets.
- **Acceptance criteria:**
  - [ ] Older-version sets cannot replace newer diagnostics for an open document.
  - [ ] Invalid locations remain inspectable messages but cannot navigate unsafely.

## ZIT-140: Implement Diagnostic Owner Lifecycle

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-139
- **Description:** Atomically replace, clear, and dispose diagnostics by owner/resource.
- **Acceptance criteria:**
  - [ ] Removing an owner clears only its diagnostics and owned resources.
  - [ ] Workspace close releases all workspace diagnostic state.

## ZIT-141: Implement Bounded Output Channels

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-012, ZIT-085
- **Description:** Provide named task, ZLS, extension, and application channels with entry, line, total-size, and retention limits.
- **Acceptance criteria:**
  - [ ] Truncation or dropped data is visible rather than silent.
  - [ ] Output cannot resize storage without documented bounds.

## ZIT-142: Implement the Problems View

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-085, ZIT-139, ZIT-140
- **Description:** Present problems grouped or filtered by severity, owner, and workspace with stable keyboard navigation.
- **Acceptance criteria:**
  - [ ] Updates preserve coherent focus and selection where possible.
  - [ ] Empty, loading, stale, and error states are explicit and accessible.

## ZIT-143: Validate Problem Navigation

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-092, ZIT-101, ZIT-139, ZIT-142
- **Description:** Revalidate resource and range against current workspace/document state when a problem is invoked.
- **Acceptance criteria:**
  - [ ] Changed, deleted, external, and malformed locations fail safely.
  - [ ] Valid problems open the correct resource and selection.

## ZIT-144: Verify Diagnostic Ordering, Output Limits, and Redaction

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-140, ZIT-141, ZIT-142, ZIT-143
- **Description:** Stress stale diagnostic ordering, owner cleanup, output floods, invalid bytes, limits, and sensitive-field redaction.
- **Acceptance criteria:**
  - [ ] Stress cases remain responsive and within memory limits.
  - [ ] Logs/output exclude document content and configured sensitive fields by default.
