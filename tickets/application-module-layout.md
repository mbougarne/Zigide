# Application Module Layout

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Create the minimal Zig product build graph and enforce inward module dependencies.
- **Architecture:** [Source boundaries](../docs/architecture/02-system-architecture.md#source-boundaries), [ADR-0001](../docs/architecture/decisions/0001-zig-first-modular-architecture.md)

## ZIT-003: Create Product Source and Test Directories

- **Status:** Ready
- **Priority:** P0
- **Estimate:** 0.5-1 day
- **Dependencies:** None
- **Description:** Add the initial product and test directory structure without speculative implementation files.
- **Acceptance criteria:**
  - [ ] Directories represent `foundation`, `text`, `workspace`, `commands`, `application`, `ports`, `adapters`, `ui`, and `app` responsibilities.
  - [ ] No placeholder APIs or dead modules are introduced merely to fill the tree.

## ZIT-004: Declare Product Library Modules

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-003
- **Description:** Define the reusable Zig modules and their legal import directions in `build.zig`.
- **Acceptance criteria:**
  - [ ] Domain modules do not import UI, platform adapters, ZLS, or extension implementations.
  - [ ] The build graph exposes only the imports each module requires.

## ZIT-005: Add the Zigide Executable Target

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 0.5-1 day
- **Dependencies:** ZIT-004
- **Description:** Add a minimal executable and composition root that starts and exits deterministically.
- **Acceptance criteria:**
  - [ ] `zig build` produces the Zigide executable with the pinned Zig version.
  - [ ] Running the executable performs no hidden filesystem, network, task, or extension action.

## ZIT-006: Add Product Unit and Integration Test Targets

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-004
- **Description:** Create product-focused unit and integration test roots and wire them into the build.
- **Acceptance criteria:**
  - [ ] Product tests run separately and as part of `zig build check`.
  - [ ] Integration fixtures have isolated temporary workspace and child-process boundaries.

## ZIT-007: Enforce Module Dependency Boundaries

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-004, ZIT-006
- **Description:** Add a maintainable check or build-graph test that prevents forbidden inward-dependency violations.
- **Acceptance criteria:**
  - [ ] A deliberate forbidden import causes the check to fail in a controlled test.
  - [ ] The documented module graph matches the enforced build graph.
