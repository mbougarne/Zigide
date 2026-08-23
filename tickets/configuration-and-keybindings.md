# Configuration and Keybindings

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Provide validated layered settings and deterministic keybinding resolution with safe persistence.
- **Architecture:** [Services](../docs/architecture/02-system-architecture.md#services), [Local data](../docs/architecture/04-data-safety-and-operations.md#local-data)

## ZIT-071: Define Core Setting Descriptors and Defaults

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-014
- **Description:** Define setting keys, types, defaults, scope, and validation for first-release behavior.
- **Acceptance criteria:**
  - [ ] Duplicate keys and invalid defaults fail tests.
  - [ ] Descriptors do not expose extension settings before the public extension contract exists.

## ZIT-072: Implement Configuration Layer Merging

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-071
- **Description:** Merge defaults, user settings, and workspace settings using documented precedence.
- **Acceptance criteria:**
  - [ ] Effective values update correctly when a layer is added, changed, or removed.
  - [ ] Change events identify affected keys and scope.

## ZIT-073: Parse Settings with Partial Diagnostics

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-064, ZIT-071
- **Description:** Parse JSON settings and report unknown or invalid entries without discarding valid siblings.
- **Acceptance criteria:**
  - [ ] Malformed documents and wrong types produce actionable diagnostics.
  - [ ] Valid values remain available when unrelated entries are invalid.

## ZIT-074: Parse and Resolve Keybindings

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-016, ZIT-073
- **Description:** Parse key chords and resolve conflicts deterministically against command preconditions.
- **Acceptance criteria:**
  - [ ] Resolution order and conflicts are inspectable and covered by tests.
  - [ ] Invalid bindings cannot invoke commands or disable unrelated valid bindings.

## ZIT-075: Persist and Watch Configuration Atomically

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-066, ZIT-072, ZIT-073
- **Description:** Atomically update editable settings/keybinding files and apply valid external changes on the application thread.
- **Acceptance criteria:**
  - [ ] Interrupted writes preserve the last valid file.
  - [ ] Watch reloads are versioned and stale results are ignored.

## ZIT-076: Expose Configuration and Keybinding Commands

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-016, ZIT-074, ZIT-075
- **Description:** Add commands to inspect effective settings, conflicts, and editable configuration resources without embedding UI policy.
- **Acceptance criteria:**
  - [ ] Commands report source scope and validation diagnostics.
  - [ ] Editing commands never overwrite invalid user content silently.
