# Protocol Framing and ZLS Spike

- **Type:** Feature
- **Milestone:** 0 - Foundations and Spikes
- **Goal:** Prove bounded shared framing and child-process transport against a real ZLS process.
- **Architecture:** [External protocols](../docs/architecture/02-system-architecture.md#external-protocols), [ADR-0003](../docs/architecture/decisions/0003-open-versioned-protocols.md)

## ZIT-020: Implement Incremental Content-Length Decoding

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-004
- **Description:** Decode complete `Content-Length` frames from arbitrary byte chunks without assuming read boundaries.
- **Acceptance criteria:**
  - [ ] Split headers, split bodies, combined frames, and extra supported headers decode correctly.
  - [ ] Truncated and malformed input returns bounded contextual errors.

## ZIT-021: Implement Framing Encoder and Size Limits

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-020
- **Description:** Encode framed JSON payloads and reject advertised or actual payloads above configured limits.
- **Acceptance criteria:**
  - [ ] Encoded output round-trips through the decoder.
  - [ ] Oversized lengths are rejected before proportional allocation.

## ZIT-022: Implement JSON-RPC Correlation Prototype

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-008, ZIT-021
- **Description:** Correlate JSON-RPC requests, responses, notifications, and errors over the framed transport.
- **Acceptance criteria:**
  - [ ] Unknown, duplicate, and late response IDs are handled without corrupting pending state.
  - [ ] Pending request resources are released on every terminal path.

## ZIT-023: Prototype Protocol Cancellation and Deadlines

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-009, ZIT-022
- **Description:** Propagate cancellation and request deadlines through the prototype without applying late results.
- **Acceptance criteria:**
  - [ ] Cancelled requests leave no applicable result or pending-resource leak.
  - [ ] Timeout and explicit cancellation remain distinguishable.

## ZIT-024: Implement Child-Process Standard-I/O Transport

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-019, ZIT-021
- **Description:** Spawn a child executable with argument arrays and transport framed messages over standard input/output.
- **Acceptance criteria:**
  - [ ] Large simultaneous output streams cannot deadlock the child or parent.
  - [ ] Spawn, pipe close, nonzero exit, and termination failures are observable.

## ZIT-025: Complete a Real ZLS Initialization Fixture

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-022, ZIT-024
- **Description:** Initialize and cleanly stop a recorded ZLS version against a temporary Zig workspace.
- **Acceptance criteria:**
  - [ ] Initialize, initialized, shutdown, and exit complete through the adapter spike.
  - [ ] The fixture records exact Zig, ZLS, workspace, and command assumptions.

## ZIT-026: Fuzz and Stress the Framing Prototype

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-020, ZIT-021, ZIT-022, ZIT-023
- **Description:** Fuzz framing and dispatch with malformed, fragmented, combined, oversized, and cancelled message streams.
- **Acceptance criteria:**
  - [ ] No generated input causes unbounded allocation, crash, hang, or leak.
  - [ ] Reproducible regression fixtures are retained for discovered defects.
