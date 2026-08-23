# Extension Supervisor

- **Type:** Feature
- **Milestone:** 3 - Extension Minimum
- **Goal:** Launch, initialize, communicate with, stop, isolate, and boundedly restart extension processes.
- **Architecture:** [Runtime boundary](../docs/architecture/03-extension-model.md#runtime-boundary), [Activation and lifecycle](../docs/architecture/03-extension-model.md#activation-and-lifecycle)

## ZIT-161: Implement the Extension Lifecycle State Machine

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-124, ZIT-159
- **Description:** Implement discovered, validated, inactive, starting, active, stopping, stopped, and failed states.
- **Acceptance criteria:**
  - [ ] Illegal transitions fail without corrupting supervisor state.
  - [ ] State changes are observable and release owned resources.

## ZIT-162: Launch Extension Processes with a Restricted Environment

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-117, ZIT-152, ZIT-157, ZIT-161
- **Description:** Launch one process per active extension with argument arrays, documented environment exposure, framed stdout/stdin, and stderr logs.
- **Acceptance criteria:**
  - [ ] Launch uses the validated entrypoint and working directory.
  - [ ] Environment restriction is documented without claiming sandbox enforcement.

## ZIT-163: Implement Extension Initialization Handshake

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-150, ZIT-153, ZIT-162
- **Description:** Negotiate version, identity, capabilities, grants, roots, and limits before activation completes.
- **Acceptance criteria:**
  - [ ] Incompatible or invalid peers fail before contribution calls are dispatched.
  - [ ] Granted state matches the validated manifest and user-visible permissions.

## ZIT-164: Dispatch Extension Requests and Notifications

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-151, ZIT-163
- **Description:** Correlate, validate, and dispatch approved protocol methods between the application and extension.
- **Acceptance criteria:**
  - [ ] Unknown, duplicate, late, and wrong-shape messages fail safely.
  - [ ] Dispatch never occurs on the mutable-state owner from an I/O callback directly.

## ZIT-165: Enforce Extension Deadlines and Cancellation

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-009, ZIT-153, ZIT-164
- **Description:** Enforce startup, request, cancellation, and shutdown deadlines and clear pending ownership.
- **Acceptance criteria:**
  - [ ] A non-responsive extension cannot indefinitely block a command or editor input.
  - [ ] Late results after cancellation are ignored and resources released.

## ZIT-166: Capture Bounded Extension Logs

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-141, ZIT-153, ZIT-162
- **Description:** Route extension stderr into an owned output channel with redaction and retention limits.
- **Acceptance criteria:**
  - [ ] Log floods are truncated visibly and cannot block process I/O.
  - [ ] Sensitive environment values are not copied into logs automatically.

## ZIT-167: Isolate Crashes and Apply Bounded Restart

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-161, ZIT-164, ZIT-165
- **Description:** Convert unexpected exit and broken transport into extension-owned failure and apply a visible bounded restart policy.
- **Acceptance criteria:**
  - [ ] Extension crash cannot terminate the IDE or another extension.
  - [ ] Deterministic startup failures do not restart indefinitely.

## ZIT-168: Implement Extension Shutdown and Reaping

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-165, ZIT-167
- **Description:** Request graceful shutdown, enforce deadline, force termination if required, reap the child, and release pending calls.
- **Acceptance criteria:**
  - [ ] IDE shutdown leaves no extension child processes or pending-request leaks.
  - [ ] Shutdown refusal is visible and does not stall application exit indefinitely.
