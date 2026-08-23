# macOS Application Shell

- **Type:** Feature
- **Milestone:** 1 - Dependable Editor
- **Goal:** Build the chosen-toolkit application lifecycle and stable explorer/editor/panel/status layout.
- **Architecture:** [System shape](../docs/architecture/02-system-architecture.md#shape), [ADR-0004](../docs/architecture/decisions/0004-ui-toolkit-selection.md)

## ZIT-084: Implement macOS Application Lifecycle

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-018, ZIT-041
- **Description:** Connect native application launch, activation, reopen, and termination requests to the application lifecycle.
- **Acceptance criteria:**
  - [ ] Launch and termination are deterministic on macOS arm64.
  - [ ] Termination follows dirty-document decisions and shutdown ordering.

## ZIT-085: Implement the Main Window and Layout

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-084
- **Description:** Create stable explorer, editor, bottom-panel, and status regions with responsive constraints.
- **Acceptance criteria:**
  - [ ] Resize and scale-factor changes do not overlap or lose core surfaces.
  - [ ] Stable region dimensions prevent dynamic content from shifting unrelated layout.

## ZIT-086: Implement UI Scheduling to the Application Thread

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-014, ZIT-084
- **Description:** Marshal native events and background results to the single mutable-state owner.
- **Acceptance criteria:**
  - [ ] UI callbacks do not mutate domain state from worker threads.
  - [ ] Closed or stale view work is discarded safely.

## ZIT-087: Establish Shell Focus and Accessibility Regions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-085
- **Description:** Expose accessible region names and a predictable keyboard focus order for the shell.
- **Acceptance criteria:**
  - [ ] Core regions are reachable and identifiable without a mouse.
  - [ ] Focus remains coherent after panel visibility and document changes.

## ZIT-088: Present Startup and Fatal Initialization Errors

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-011, ZIT-084
- **Description:** Show actionable initialization errors without crashing silently or exposing sensitive internals.
- **Acceptance criteria:**
  - [ ] Users can distinguish configuration, resource, adapter, and unsupported-environment failures.
  - [ ] Error presentation remains available when normal workspace services fail.

## ZIT-089: Verify Shell Lifecycle and Packaging Smoke Tests

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-085, ZIT-086, ZIT-087, ZIT-088
- **Description:** Exercise launch, resize, focus, close, reopen, failure, and app-bundle smoke paths on the target Mac.
- **Acceptance criteria:**
  - [ ] Tests and manual evidence cover all shell lifecycle states.
  - [ ] UI toolkit types remain confined to UI adapter modules.
