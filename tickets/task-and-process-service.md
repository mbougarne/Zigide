# Task and Process Service

- **Type:** Feature
- **Milestone:** 2 - Zig Work Loop
- **Goal:** Run `zig build` safely with streamed output, cancellation, deadlines, and exact completion status.
- **Architecture:** [Security boundaries](../docs/architecture/04-data-safety-and-operations.md#security-boundaries), [Failure model](../docs/architecture/02-system-architecture.md#failure-model)

## ZIT-116: Define Task Definitions and First-Run Trust

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-016, ZIT-052
- **Description:** Define executable, arguments, working directory, environment allowlist, and a first-run confirmation showing what will execute.
- **Acceptance criteria:**
  - [ ] Opening a workspace never auto-runs a task.
  - [ ] Trust decisions identify the exact executable and working directory.

## ZIT-117: Implement Safe Child-Process Spawn

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-024, ZIT-116
- **Description:** Spawn executable argument arrays without implicit shell interpolation and capture process identity.
- **Acceptance criteria:**
  - [ ] Workspace-controlled arguments never pass through a shell string.
  - [ ] Missing executable, invalid directory, and permission failures are distinct.

## ZIT-118: Stream Standard Output and Error

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-117, ZIT-141
- **Description:** Drain both streams concurrently into bounded output channels while retaining ordering metadata.
- **Acceptance criteria:**
  - [ ] Large simultaneous streams do not deadlock or grow memory without bound.
  - [ ] Invalid bytes and oversized lines follow documented display behavior.

## ZIT-119: Cancel Task Process Trees

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-009, ZIT-117
- **Description:** Cancel the child and its relevant process tree using a documented graceful-then-force deadline.
- **Acceptance criteria:**
  - [ ] Cancellation completion reports whether graceful or forced termination occurred.
  - [ ] Tested descendants do not remain running after the deadline.

## ZIT-120: Implement Task Timeouts and Reaping

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-117, ZIT-119
- **Description:** Enforce optional deadlines, reap every child, and classify exit code, signal, timeout, cancellation, and spawn failure.
- **Acceptance criteria:**
  - [ ] Every terminal path releases pipes, pending work, and process handles.
  - [ ] Timeout remains distinguishable from user cancellation.

## ZIT-121: Add the Zig Build Task and Diagnostic Parsing

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-116, ZIT-118, ZIT-120, ZIT-139
- **Description:** Provide `zig build` as the first task and parse stable file/range diagnostics while retaining raw output.
- **Acceptance criteria:**
  - [ ] Successful and failing builds report exact completion state.
  - [ ] Parsed paths and ranges are validated before diagnostic navigation.

## ZIT-122: Stress-Test Task Execution

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-118, ZIT-119, ZIT-120, ZIT-121
- **Description:** Test missing programs, failures, large output, hangs, cancellation, timeouts, descendants, and repeated runs.
- **Acceptance criteria:**
  - [ ] Stress cases do not freeze editing, leak children, or exceed output limits.
  - [ ] Real sample-project builds pass on the target Mac.
