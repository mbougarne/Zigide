# Foundation Primitives

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Implement only the shared primitives required by concrete application services.
- **Architecture:** [State and concurrency](../docs/architecture/02-system-architecture.md#state-and-concurrency), [Observability](../docs/architecture/04-data-safety-and-operations.md#observability)

## ZIT-008: Implement Typed IDs and Injectable Clocks

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-004
- **Description:** Provide typed operation/correlation IDs and production/test clocks with deterministic substitutes.
- **Acceptance criteria:**
  - [ ] IDs from unrelated domains cannot be mixed accidentally.
  - [ ] Tests control time and ID generation without sleeping or global mutation.

## ZIT-009: Implement Cooperative Cancellation

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-008
- **Description:** Define cancellation ownership, idempotent signalling, observation, and cleanup for background work.
- **Acceptance criteria:**
  - [ ] Repeated cancellation is safe and observable.
  - [ ] Cancellation resources are released on success, failure, and abandonment paths.

## ZIT-010: Implement Scoped Events and Subscriptions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-004
- **Description:** Add typed events whose subscriptions return explicit disposable handles.
- **Acceptance criteria:**
  - [ ] Subscribe, dispatch, unsubscribe, and unsubscribe-during-dispatch behavior is tested.
  - [ ] Event cleanup releases owned callbacks and context without leaks.

## ZIT-011: Define Contextual Application Errors

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-004
- **Description:** Establish error categories and context propagation without hiding Zig error unions behind an exception framework.
- **Acceptance criteria:**
  - [ ] Expected boundary failures retain operation and resource context.
  - [ ] Errors can be logged and shown without exposing sensitive payloads.

## ZIT-012: Define Structured Logging Contracts

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-008, ZIT-011
- **Description:** Define structured log events and a replaceable sink interface for application and test use.
- **Acceptance criteria:**
  - [ ] Events include timestamp, severity, subsystem, event name, and correlation ID.
  - [ ] Document contents, prompts, tokens, and environment dumps are excluded by default.

## ZIT-013: Verify Foundation Allocation and Lifetime Rules

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-008, ZIT-009, ZIT-010, ZIT-011, ZIT-012
- **Description:** Document allocator ownership and test success, failure, disposal, and cancellation paths with Zig's test allocator.
- **Acceptance criteria:**
  - [ ] Every public owning type identifies its allocator and deinitialization responsibility.
  - [ ] Foundation tests report no leaks or double frees.
