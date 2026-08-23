# Explorer, Command Palette, and Status

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Add efficient workspace navigation, command discovery, open-document control, and concise state feedback.
- **Architecture:** [Initial user journey](../docs/architecture/01-vision-and-scope.md#initial-user-journey), [Command flow](../docs/architecture/02-system-architecture.md#command-flow)

## ZIT-100: Implement the Explorer Tree Model

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-053, ZIT-064
- **Description:** Load one workspace tree lazily or in bounded batches and represent loading, empty, and error states.
- **Acceptance criteria:**
  - [ ] Expand/collapse does not synchronously traverse the full workspace.
  - [ ] Unreadable and changing directories do not break sibling navigation.

## ZIT-101: Enforce Explorer Path Boundaries

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-052, ZIT-100
- **Description:** Apply normalized path, symlink, and traversal policy before exposing resources through the explorer.
- **Acceptance criteria:**
  - [ ] Accidental traversal and symlink loops cannot expose unapproved paths or recurse indefinitely.
  - [ ] Boundary failures are visible and tested.

## ZIT-102: Implement Open-Document Controls

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-054, ZIT-055, ZIT-056, ZIT-085
- **Description:** Show, activate, and close open documents with visible dirty state using tabs or an equivalent stable control.
- **Acceptance criteria:**
  - [ ] Activation tracks the application active document.
  - [ ] Close uses dirty-document decisions and never discards silently.

## ZIT-103: Index and Filter Command Palette Entries

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-015, ZIT-085
- **Description:** Build a searchable palette index from registered command titles and enablement metadata.
- **Acceptance criteria:**
  - [ ] Filtering is deterministic and responsive for the expected command count.
  - [ ] Disabled commands remain discoverable with a reason when available.

## ZIT-104: Execute Commands from the Palette

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-016, ZIT-103
- **Description:** Dispatch selected palette commands and present progress, cancellation, results, and errors.
- **Acceptance criteria:**
  - [ ] The palette uses the same command path as keys and tests.
  - [ ] Execution cannot use a stale or disposed command registration.

## ZIT-105: Implement the Status Surface

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-049, ZIT-055, ZIT-085
- **Description:** Show cursor, selection, encoding, line endings, dirty state, and actionable application status from typed events.
- **Acceptance criteria:**
  - [ ] Status updates do not poll mutable domain state.
  - [ ] Dynamic content remains bounded and does not shift unrelated layout.

## ZIT-106: Verify Navigation Keyboard and Accessibility Flows

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-087, ZIT-100, ZIT-102, ZIT-104, ZIT-105
- **Description:** Verify explorer, open-document, palette, status, and editor transitions using keyboard and VoiceOver.
- **Acceptance criteria:**
  - [ ] Core navigation completes without a mouse with visible, logical focus.
  - [ ] Controls expose concise accessible names, states, and errors.
