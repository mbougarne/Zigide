# Extension Compatibility and Failure Tests

- **Type:** Feature
- **Milestone:** 3 - Extension Minimum
- **Goal:** Protect every supported protocol version against malformed, slow, crashing, and resource-exhausting peers.
- **Architecture:** [SDK and compatibility](../docs/architecture/03-extension-model.md#sdk-and-compatibility), [Verification strategy](../docs/architecture/04-data-safety-and-operations.md#verification-strategy)

## ZIT-183: Implement Supported-Version Fixtures

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-154, ZIT-163
- **Description:** Run a successful handshake and representative contribution flow for every supported major/minor combination.
- **Acceptance criteria:**
  - [ ] Unsupported major versions fail before activation.
  - [ ] Forward-minor optional fields behave exactly as the compatibility ADR states.

## ZIT-184: Build Malformed Extension Peers

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-160, ZIT-163, ZIT-164
- **Description:** Generate malformed framing, JSON, handshake, IDs, capabilities, methods, paths, and contribution payloads.
- **Acceptance criteria:**
  - [ ] Each malformed class produces deterministic isolated failure.
  - [ ] The IDE process remains alive and other extensions remain functional.

## ZIT-185: Test Extension Timeouts and Crashes

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-165, ZIT-167, ZIT-168
- **Description:** Simulate slow startup, ignored cancellation, request hangs, crash, shutdown refusal, and restart loops.
- **Acceptance criteria:**
  - [ ] Every case meets documented deadlines and bounded restart policy.
  - [ ] No child or pending-request resource remains after completion.

## ZIT-186: Test Extension Flood and Size Limits

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-153, ZIT-166, ZIT-175
- **Description:** Flood frames, logs, output, notifications, diagnostics, and requests to verify all resource limits.
- **Acceptance criteria:**
  - [ ] Memory and UI responsiveness remain within documented bounds.
  - [ ] Truncation and failure are visible and owner-specific.

## ZIT-187: Fuzz Manifest, Framing, and Protocol Dispatch

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-148, ZIT-156, ZIT-164
- **Description:** Add fuzz targets and retain a reproducible regression corpus for discovered parsing and lifecycle defects.
- **Acceptance criteria:**
  - [ ] Fuzz input cannot cause crash, hang, unbounded allocation, or leak.
  - [ ] Corpus cases run deterministically in ordinary tests.

## ZIT-188: Run Extension Compatibility and Leak Tests in CI

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-182, ZIT-183, ZIT-184, ZIT-185, ZIT-186, ZIT-187
- **Description:** Add bounded CI execution for fixtures, examples, failures, deadlines, and child-process cleanup.
- **Acceptance criteria:**
  - [ ] CI identifies the exact failed fixture and supported version.
  - [ ] The suite completes under a documented maximum duration without leaked processes.
