# Dependable Editor

- **Type:** Epic
- **Milestone:** 1 - Dependable Editor
- **Goal:** Deliver a recoverable macOS editor that safely opens, edits, saves, and restores real Zig files.
- **Architecture:** [Vision and scope](../docs/architecture/01-vision-and-scope.md), [Delivery roadmap](../docs/architecture/05-delivery-roadmap.md)

## ZIT-042: Define the Dependable-Editor Exit Suite

- **Status:** Done
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-002
- **Description:** Map Milestone 1 outcomes to automated domain, integration, crash, UI, accessibility, and performance evidence.
- **Acceptance criteria:**
  - [x] Every Milestone 1 roadmap outcome has an owning ticket and completion check.
  - [x] Data-loss, accessibility, and critical-latency failures are explicit milestone blockers.

The [maintained exit suite](../tests/dependable_editor/README.md) maps every roadmap
deliverable and exit outcome to owners, checks and blocking evidence. Its Zig
contract/parser tests run through `zig build dependable-editor-test` and the
aggregate checks. This completes the suite definition, not milestone qualification.

## ZIT-043: Verify the End-to-End Editing Journey

- **Status:** Blocked
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-051, ZIT-057, ZIT-063, ZIT-070, ZIT-076, ZIT-083, ZIT-089, ZIT-099, ZIT-106
- **Description:** Exercise project open, multi-file editing, undo/redo, save, conflict handling, settings, recovery, and keyboard-accessible navigation in one release-like flow.
- **Acceptance criteria:**
  - [ ] The journey runs on macOS arm64 with exact build and fixture details recorded.
  - [ ] Failures preserve user data and produce actionable state rather than silent loss.

All nine direct dependency tickets remain Planned at the PR #9 baseline. ADR-0004
also remains Proposed and blocks the production editor view. The
[journey procedure and readiness command](../tests/dependable_editor/README.md#release-like-journey-zit-043)
provide maintained fixtures and a Zig preflight that reports these blockers with
exact build/fixture identity. The journey has not run; data-preservation, physical
IME, VoiceOver and production latency acceptance remain unverified. Implementing
the prerequisite features or accepting the UI decision is separate work.
