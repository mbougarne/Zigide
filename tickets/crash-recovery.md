# Crash Recovery

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Snapshot dirty documents and restore them safely without overwriting newer workspace files.
- **Architecture:** [Recovery](../docs/architecture/04-data-safety-and-operations.md#recovery), [Failure model](../docs/architecture/02-system-architecture.md#failure-model)

## ZIT-077: Define the Recovery Format

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-049, ZIT-052
- **Description:** Define a versioned recovery manifest and snapshot format containing resource, base metadata, document version, encoding, line ending, and checksum.
- **Acceptance criteria:**
  - [ ] Unsupported versions and malformed fields fail without blocking unrelated snapshots.
  - [ ] Format fixtures are stable and reviewed as persistence contracts.

## ZIT-078: Implement Atomic Recovery Snapshot Writes

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-066, ZIT-077
- **Description:** Write complete snapshots outside the workspace using interruption-safe replacement.
- **Acceptance criteria:**
  - [ ] A failed write preserves the previous valid snapshot.
  - [ ] Snapshot paths cannot escape the designated recovery store.

## ZIT-079: Schedule Bounded Recovery Snapshots

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-009, ZIT-055, ZIT-078
- **Description:** Snapshot dirty documents on a bounded cadence and focus loss without blocking editor input.
- **Acceptance criteria:**
  - [ ] Repeated edits coalesce writes while preserving the documented recovery cadence.
  - [ ] Closed or clean documents do not receive stale background snapshots.

## ZIT-080: Discover Recoverable Sessions at Startup

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-077, ZIT-078
- **Description:** Enumerate and validate recovery manifests during startup without opening or overwriting workspace files.
- **Acceptance criteria:**
  - [ ] Corrupt, partial, and orphaned records are isolated and reported.
  - [ ] Valid sibling recovery sessions remain available.

## ZIT-081: Implement Recovery Divergence Decisions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-056, ZIT-068, ZIT-080
- **Description:** Compare snapshot base metadata with disk and request restore, inspect, or discard decisions when state diverges.
- **Acceptance criteria:**
  - [ ] A newer disk file is never overwritten automatically.
  - [ ] Cancel preserves both snapshot and disk state.

## ZIT-082: Clean Up Resolved Recovery Data

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-078, ZIT-081
- **Description:** Remove only matching snapshots after verified save or explicit discard and prune safe orphan data.
- **Acceptance criteria:**
  - [ ] Cleanup cannot remove another document or session's recovery state.
  - [ ] Cleanup failures are logged without invalidating a successful save.

## ZIT-083: Crash-Test Recovery Guarantees

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-079, ZIT-080, ZIT-081, ZIT-082
- **Description:** Terminate the process at representative snapshot stages and verify recovery within the documented cadence.
- **Acceptance criteria:**
  - [ ] Acknowledged edits covered by the cadence recover after tested crashes.
  - [ ] Corruption and interruption tests never overwrite newer disk content.
