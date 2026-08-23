# LSP Client Lifecycle

- **Type:** Feature
- **Milestone:** 2 - Zig Work Loop
- **Goal:** Supervise ZLS initialization, document sync, requests, cancellation, shutdown, and bounded restart.
- **Architecture:** [External protocols](../docs/architecture/02-system-architecture.md#external-protocols), [ADR-0003](../docs/architecture/decisions/0003-open-versioned-protocols.md)

## ZIT-123: Configure and Identify the ZLS Executable

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-073, ZIT-117
- **Description:** Resolve a configured or discoverable ZLS executable and capture its version without running workspace code.
- **Acceptance criteria:**
  - [ ] Missing, invalid, unsupported, and executable failures produce actionable status.
  - [ ] Exact ZLS identity is available to logs and diagnostics safely.

## ZIT-124: Implement the LSP Client State Machine

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-022, ZIT-123
- **Description:** Model stopped, starting, initializing, ready, stopping, failed, and restart-wait states explicitly.
- **Acceptance criteria:**
  - [ ] Illegal transitions fail without corrupting client state.
  - [ ] Lifecycle state changes are observable and disposable.

## ZIT-125: Implement Initialization and Capability Negotiation

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-053, ZIT-124
- **Description:** Initialize one local workspace and retain only validated server capabilities.
- **Acceptance criteria:**
  - [ ] Unsupported capabilities disable dependent behavior.
  - [ ] Initialization messages obey framing and payload limits.

## ZIT-126: Implement Pending Request Correlation

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-022, ZIT-124
- **Description:** Track request IDs, expected response types, deadlines, and completion ownership.
- **Acceptance criteria:**
  - [ ] Unknown, duplicate, late, and wrong-shape responses cannot corrupt pending state.
  - [ ] Pending resources are released after every terminal result.

## ZIT-127: Synchronize Document Open, Change, Save, and Close

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-046, ZIT-054, ZIT-057, ZIT-125
- **Description:** Translate document lifecycle and validated incremental edits into LSP notifications with monotonic versions.
- **Acceptance criteria:**
  - [ ] LSP position/version conversions remain inside the adapter.
  - [ ] Closed or stale document changes are never sent as current state.

## ZIT-128: Implement LSP Cancellation and Deadlines

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-009, ZIT-126
- **Description:** Cancel pending requests when explicitly requested, superseded, timed out, or invalidated by document closure.
- **Acceptance criteria:**
  - [ ] Late responses after cancellation are ignored safely.
  - [ ] Cancellation and timeout remain distinguishable to callers.

## ZIT-129: Validate Incoming LSP Messages

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-021, ZIT-126
- **Description:** Bound and validate message shape, IDs, methods, paths, ranges, and payload sizes before dispatch.
- **Acceptance criteria:**
  - [ ] Malformed, oversized, unknown, and out-of-order messages do not crash Zigide.
  - [ ] Invalid paths/ranges cannot mutate document or workspace state.

## ZIT-130: Implement Graceful Shutdown and Bounded Restart

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-124, ZIT-126, ZIT-128, ZIT-129
- **Description:** Request protocol shutdown, enforce a process deadline, surface crashes, and restart only within a visible bounded policy.
- **Acceptance criteria:**
  - [ ] Repeated deterministic startup failures do not restart indefinitely.
  - [ ] Shutdown and crash tests leave no child or pending-request leak.
