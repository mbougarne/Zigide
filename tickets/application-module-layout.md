# Application Module Layout

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Create the minimal Zig product build graph and enforce inward module dependencies.
- **Architecture:** [Source boundaries](../docs/architecture/02-system-architecture.md#source-boundaries), [ADR-0001](../docs/architecture/decisions/0001-zig-first-modular-architecture.md)
- **Verification evidence:** [ZIT-003–ZIT-007 evidence addendum](../docs/milestones/application-module-layout-evidence.md)

## ZIT-003: Create Product Source and Test Directories

- **Status:** Done
- **Priority:** P0
- **Estimate:** 0.5-1 day
- **Dependencies:** None
- **Description:** Add the initial product and test directory structure without speculative implementation files.
- **Acceptance criteria:**
  - [x] Directories represent `foundation`, `text`, `workspace`, `commands`, `application`, `ports`, `adapters`, `ui`, and `composition` responsibilities.
  - [x] No placeholder public APIs or speculative product implementations were introduced merely to fill the tree.
- **Evidence:** `src/` contains the module roots; the roots expose no product APIs before their implementation tickets.

## ZIT-004: Declare Product Library Modules

- **Status:** Done
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-003
- **Description:** Define the reusable Zig modules and their legal import directions in `build.zig`.
- **Acceptance criteria:**
  - [x] Domain modules do not import UI, platform adapters, ZLS, or extension implementations.
  - [x] The build graph exposes only the declared direct imports for each module.
- **Evidence:** `build.zig` declares private module imports; [System Architecture](../docs/architecture/02-system-architecture.md#source-boundaries) documents the same graph.

## ZIT-005: Add the Zigide Executable Target

- **Status:** Done
- **Priority:** P0
- **Estimate:** 0.5-1 day
- **Dependencies:** ZIT-004
- **Description:** Add a minimal executable and composition root that starts and exits deterministically.
- **Acceptance criteria:**
  - [x] `zig build` produces the Zigide executable with the pinned Zig version.
  - [x] Running the executable performs no hidden filesystem, network, task, or extension action.
- **Evidence:** `src/composition/main.zig`; `zig build` and `zig build run`.

## ZIT-006: Add Product Unit and Integration Test Targets

- **Status:** Done
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-004
- **Description:** Create product-focused unit and integration test roots and wire them into the build.
- **Acceptance criteria:**
  - [x] Product tests run separately and as part of `zig build check`.
  - [x] Integration fixtures use an isolated temporary workspace and an explicitly bounded child-process environment.
- **Evidence:** `tests/unit.zig`, `tests/integration.zig`; `zig build unit-test`, `zig build integration-test`, and `zig build check`.

## ZIT-007: Enforce Module Dependency Boundaries

- **Status:** Done
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-004, ZIT-006
- **Description:** Add a maintainable check or build-graph test that prevents forbidden inward-dependency violations.
- **Acceptance criteria:**
  - [x] A deliberate forbidden import is rejected by a controlled expected-failure compile test.
  - [x] The documented module graph matches the enforced build graph.
- **Evidence:** `tests/fixtures/forbidden_domain_ui_import.zig`; `build.zig`; [System Architecture](../docs/architecture/02-system-architecture.md#source-boundaries); `zig build check`.
