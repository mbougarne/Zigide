# Zig Extension SDK and Examples

- **Type:** Feature
- **Milestone:** 3 - Extension Minimum
- **Goal:** Publish a standalone Zig SDK and examples that use only the public wire protocol.
- **Architecture:** [SDK and compatibility](../docs/architecture/03-extension-model.md#sdk-and-compatibility), [ADR-0002](../docs/architecture/decisions/0002-out-of-process-extensions.md)

## ZIT-177: Define the Public Zig SDK Package

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-154
- **Description:** Create a separately importable SDK package whose API mirrors public protocol concepts without private Zigide imports.
- **Acceptance criteria:**
  - [ ] SDK dependency review finds no product-internal module import.
  - [ ] Public ownership and allocator rules are documented.

## ZIT-178: Implement SDK Framing and JSON-RPC

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-020, ZIT-021, ZIT-151, ZIT-177
- **Description:** Implement protocol framing, messages, correlation, errors, and bounded transport for extension executables.
- **Acceptance criteria:**
  - [ ] SDK output passes Zigide protocol fixtures.
  - [ ] Malformed input, closed pipes, and allocation failures release resources.

## ZIT-179: Implement SDK Initialization and Cancellation

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-150, ZIT-153, ZIT-178
- **Description:** Expose initialization identity/capabilities/grants plus handler cancellation and graceful shutdown.
- **Acceptance criteria:**
  - [ ] Handlers can observe cancellation without accessing transport internals.
  - [ ] Unsupported versions/capabilities fail before handlers run.

## ZIT-180: Implement Typed SDK Contribution Helpers

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-151, ZIT-179
- **Description:** Add typed command, task, document, diagnostic, notification, and output helpers for version 1.
- **Acceptance criteria:**
  - [ ] Helpers preserve protocol validation and limits rather than bypassing them.
  - [ ] No helper exposes unsupported edit or UI-injection capability.

## ZIT-181: Build an SDK Test Transport

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-178, ZIT-179
- **Description:** Provide deterministic in-memory or fixture transport for extension handler tests.
- **Acceptance criteria:**
  - [ ] Tests can inject requests, cancellation, errors, closure, and malformed input.
  - [ ] Test transport follows the same ownership contract as standard I/O.

## ZIT-182: Build Command and Diagnostics Example Extensions

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-176, ZIT-180, ZIT-181
- **Description:** Package standalone examples that build independently and run through discovery, supervisor, contributions, and SDK only.
- **Acceptance criteria:**
  - [ ] Examples import no private Zigide module or local absolute path.
  - [ ] End-to-end tests demonstrate lazy command activation and owned diagnostics cleanup.
