# Zig Work Loop

- **Type:** Epic
- **Milestone:** 2 - Zig Work Loop
- **Goal:** Enable a complete local edit, search, navigate, build, diagnose, and repair workflow for Zig projects.
- **Architecture:** [Initial user journey](../docs/architecture/01-vision-and-scope.md#initial-user-journey), [Delivery roadmap](../docs/architecture/05-delivery-roadmap.md)

## ZIT-107: Build the Zig Work-Loop Sample Project

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-043
- **Description:** Create a deterministic Zig fixture with multiple files, references, diagnostics, formatting cases, build success, and build failure states.
- **Acceptance criteria:**
  - [ ] The fixture covers every Milestone 2 feature without network access.
  - [ ] Expected results are documented and versioned with the pinned Zig/ZLS assumptions.

## ZIT-108: Verify the End-to-End Zig Work Loop

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-115, ZIT-122, ZIT-130, ZIT-138, ZIT-144
- **Description:** Run the sample project through search, navigation, edit, build, diagnostics, repair, and rebuild with cancellation and failure recovery.
- **Acceptance criteria:**
  - [ ] The full workflow completes inside Zigide without blocking ordinary text input.
  - [ ] ZLS and task crashes remain isolated and visibly recoverable.
