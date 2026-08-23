# Safe File I/O

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Open and atomically save local text files without silent encoding, durability, or conflict loss.
- **Architecture:** [Local data](../docs/architecture/04-data-safety-and-operations.md#local-data), [Security boundaries](../docs/architecture/04-data-safety-and-operations.md#security-boundaries)

## ZIT-064: Implement Bounded File Reads

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-019, ZIT-052
- **Description:** Read local files under explicit size limits and capture stable metadata for later conflict checks.
- **Acceptance criteria:**
  - [ ] Missing, unreadable, non-regular, and oversized files produce distinct errors.
  - [ ] Reads cannot allocate directly from untrusted file size without limits.

## ZIT-065: Implement Text Decoding Policy

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-049, ZIT-064
- **Description:** Detect UTF-8 validity and apply the approved invalid-input policy without implicit replacement.
- **Acceptance criteria:**
  - [ ] Invalid input remains recoverable or is rejected before editable decoding, as documented.
  - [ ] Saving cannot silently destroy undecodable bytes.

## ZIT-066: Implement Atomic Save Replacement

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-019, ZIT-049
- **Description:** Write a complete temporary replacement, sync according to documented guarantees, and atomically rename it over the destination.
- **Acceptance criteria:**
  - [ ] The original remains intact until the replacement is ready.
  - [ ] Failure at tested write stages preserves dirty in-memory content and reports context.

## ZIT-067: Implement Save As and Permission Handling

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-052, ZIT-066
- **Description:** Save to a new resource identity and preserve or set permissions according to a documented macOS policy.
- **Acceptance criteria:**
  - [ ] Save As updates document identity only after successful replacement.
  - [ ] Permission errors and destination collisions leave the original document state intact.

## ZIT-068: Capture and Compare External File Metadata

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-064, ZIT-066
- **Description:** Compare stable base metadata before save and detect external modifications or replacement.
- **Acceptance criteria:**
  - [ ] External changes are detected before overwrite.
  - [ ] Metadata limitations and false-positive/negative risks are documented.

## ZIT-069: Implement External-Change Resolution Flow

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-056, ZIT-068
- **Description:** Request reload, inspect, overwrite, or cancel decisions without silently resolving disk divergence.
- **Acceptance criteria:**
  - [ ] Cancel leaves disk and in-memory state unchanged.
  - [ ] Reload cannot discard dirty edits without a separate explicit decision.

## ZIT-070: Fault-Test File Open and Save

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-065, ZIT-067, ZIT-069
- **Description:** Exercise temporary filesystems, permission failures, partial writes, rename failures, disk changes, and line-ending round trips.
- **Acceptance criteria:**
  - [ ] Tested failures do not corrupt the last valid disk file or dirty document.
  - [ ] Verified durability claims are scoped to the tested macOS/filesystem behavior.
