# Headless Application and Commands

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Compose application services without a native window and establish commands as the shared action boundary.
- **Architecture:** [Command flow](../docs/architecture/02-system-architecture.md#command-flow), [Failure model](../docs/architecture/02-system-architecture.md#failure-model)

## ZIT-014: Define Application Service Composition

- **Status:** Implemented
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-005, ZIT-013
- **Description:** Define the composition context that wires explicit services and ports without a general dependency-injection container.
- **Acceptance criteria:**
  - [x] The composition root is the only place that chooses concrete adapters.
  - [x] Headless tests can replace every external port.

## ZIT-015: Implement Command Registration and Lookup

- **Status:** Implemented
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-010, ZIT-014
- **Description:** Register stable namespaced command IDs and resolve handlers without UI ownership.
- **Acceptance criteria:**
  - [x] Duplicate and unknown IDs return explicit errors.
  - [x] Registration order does not alter lookup semantics.

Evidence for ZIT-014 and ZIT-015: [headless composition and registry addendum](../docs/milestones/headless-application-commands-evidence.md).

## ZIT-016: Validate Command Arguments and Preconditions

- **Status:** Done
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-015
- **Description:** Validate typed command arguments and enablement preconditions before invoking handlers.
- **Acceptance criteria:**
  - [x] Invalid arguments and failed preconditions do not call handlers.
  - [x] Errors distinguish unknown, disabled, invalid, cancelled, and handler-failure states.

## ZIT-017: Implement Command Registration Lifetimes

- **Status:** Done
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-015
- **Description:** Make command ownership disposable so services and future extensions can unregister cleanly.
- **Acceptance criteria:**
  - [x] Disposal removes only registrations owned by that handle.
  - [x] Dispatch cannot use freed handler context during concurrent lifecycle events.

## ZIT-018: Implement Deterministic Startup and Shutdown

- **Status:** Done
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-014
- **Description:** Implement ordered, idempotent application startup and shutdown with deadlines for future workers and child processes.
- **Acceptance criteria:**
  - [x] Shutdown rejects new commands after transition begins.
  - [x] Repeated shutdown calls preserve the documented order and release all services once.

## ZIT-019: Build Headless Port Test Doubles

- **Status:** Done
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-014, ZIT-018
- **Description:** Provide deterministic fake file, storage, clock, process, and UI-scheduling ports for behavioral tests.
- **Acceptance criteria:**
  - [x] Tests can inject successes, expected failures, delays, and cancellation without real OS effects.
  - [x] ADR-0001 headless-substitution validation is demonstrably satisfied.

Validation: [ZIT-016–019 evidence](../docs/milestones/headless-lifecycle-evidence.md).
