# Dependable Editor

- **Type:** Epic
- **Milestone:** 1 - Dependable Editor
- **Goal:** Deliver a recoverable macOS editor that safely opens, edits, saves, and restores real Zig files.
- **Architecture:** [Vision and scope](../docs/architecture/01-vision-and-scope.md), [Delivery roadmap](../docs/architecture/05-delivery-roadmap.md)

## ZIT-042: Define the Dependable-Editor Exit Suite

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-002
- **Description:** Map Milestone 1 outcomes to automated domain, integration, crash, UI, accessibility, and performance evidence.
- **Acceptance criteria:**
  - [ ] Every Milestone 1 roadmap outcome has an owning ticket and completion check.
  - [ ] Data-loss, accessibility, and critical-latency failures are explicit milestone blockers.

## ZIT-043: Verify the End-to-End Editing Journey

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-051, ZIT-057, ZIT-063, ZIT-070, ZIT-076, ZIT-083, ZIT-089, ZIT-099, ZIT-106
- **Description:** Exercise project open, multi-file editing, undo/redo, save, conflict handling, settings, recovery, and keyboard-accessible navigation in one release-like flow.
- **Acceptance criteria:**
  - [ ] The journey runs on macOS arm64 with exact build and fixture details recorded.
  - [ ] Failures preserve user data and produce actionable state rather than silent loss.
