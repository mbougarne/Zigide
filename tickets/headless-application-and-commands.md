# Headless Application and Commands

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Compose application services without a native window and establish commands as the shared action boundary.
- **Architecture:** [Command flow](../docs/architecture/02-system-architecture.md#command-flow), [Failure model](../docs/architecture/02-system-architecture.md#failure-model)

## ZIT-014: Define Application Service Composition

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-005, ZIT-013
- **Description:** Define the composition context that wires explicit services and ports without a general dependency-injection container.
- **Acceptance criteria:**
  - [ ] The composition root is the only place that chooses concrete adapters.
  - [ ] Headless tests can replace every external port.

## ZIT-015: Implement Command Registration and Lookup

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-010, ZIT-014
- **Description:** Register stable namespaced command IDs and resolve handlers without UI ownership.
- **Acceptance criteria:**
  - [ ] Duplicate and unknown IDs return explicit errors.
  - [ ] Registration order does not alter lookup semantics.

## ZIT-016: Validate Command Arguments and Preconditions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-015
- **Description:** Validate typed command arguments and enablement preconditions before invoking handlers.
- **Acceptance criteria:**
  - [ ] Invalid arguments and failed preconditions do not call handlers.
  - [ ] Errors distinguish unknown, disabled, invalid, cancelled, and handler-failure states.

## ZIT-017: Implement Command Registration Lifetimes

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-015
- **Description:** Make command ownership disposable so services and future extensions can unregister cleanly.
- **Acceptance criteria:**
  - [ ] Disposal removes only registrations owned by that handle.
  - [ ] Dispatch cannot use freed handler context during concurrent lifecycle events.

## ZIT-018: Implement Deterministic Startup and Shutdown

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-014
- **Description:** Implement ordered, idempotent application startup and shutdown with deadlines for future workers and child processes.
- **Acceptance criteria:**
  - [ ] Shutdown rejects new commands after transition begins.
  - [ ] Repeated shutdown calls preserve the documented order and release all services once.

## ZIT-019: Build Headless Port Test Doubles

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-014, ZIT-018
- **Description:** Provide deterministic fake file, storage, clock, process, and UI-scheduling ports for behavioral tests.
- **Acceptance criteria:**
  - [ ] Tests can inject successes, expected failures, delays, and cancellation without real OS effects.
  - [ ] ADR-0001 headless-substitution validation is demonstrably satisfied.
