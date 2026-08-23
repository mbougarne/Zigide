# Extension Discovery and Validation

- **Type:** Feature
- **Milestone:** 3 - Extension Minimum
- **Goal:** Discover and index local packages without executing code, while isolating invalid packages.
- **Architecture:** [Package](../docs/architecture/03-extension-model.md#package), [Security boundaries](../docs/architecture/04-data-safety-and-operations.md#security-boundaries)

## ZIT-155: Define Extension Discovery Directories

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-149
- **Description:** Define user and development extension directories and their deterministic precedence on macOS.
- **Acceptance criteria:**
  - [ ] Directories remain outside the application bundle and workspace by default.
  - [ ] Missing/unreadable directories do not prevent startup.

## ZIT-156: Parse Manifests Under Explicit Limits

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-148, ZIT-155
- **Description:** Read and validate manifests with bounded file size, JSON depth, strings, arrays, and diagnostics.
- **Acceptance criteria:**
  - [ ] Invalid JSON/schema packages fail independently.
  - [ ] Parsing performs no executable launch or dynamic library load.

## ZIT-157: Validate Extension Package Paths

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-149, ZIT-156
- **Description:** Normalize package and entrypoint paths and enforce root/symlink/executable policy.
- **Acceptance criteria:**
  - [ ] Traversal, absolute, symlink-escape, missing, and wrong-type fixtures fail.
  - [ ] Failures identify the package without exposing unrelated paths.

## ZIT-158: Resolve Duplicate and Unsupported Packages

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-147, ZIT-156
- **Description:** Detect duplicate IDs and unsupported versions using deterministic selection or rejection rules.
- **Acceptance criteria:**
  - [ ] Discovery order cannot silently choose a different duplicate.
  - [ ] Unsupported packages remain inspectable but inactive.

## ZIT-159: Index Declarative Contributions and Activation Events

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-151, ZIT-156, ZIT-158
- **Description:** Build an immutable discovery index for approved contributions and activation events without starting processes.
- **Acceptance criteria:**
  - [ ] Commands and metadata are discoverable while the package remains inactive.
  - [ ] Index ownership and invalidation are deterministic.

## ZIT-160: Adversarially Test Extension Discovery

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-156, ZIT-157, ZIT-158, ZIT-159
- **Description:** Test deep/oversized JSON, path attacks, symlink races where practical, duplicates, mixed validity, and directory changes.
- **Acceptance criteria:**
  - [ ] Invalid packages cannot block valid siblings or cause unbounded allocation.
  - [ ] Discovery produces deterministic diagnostics and no process execution.
