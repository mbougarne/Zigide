# Extension Minimum

- **Type:** Epic
- **Milestone:** 3 - Extension Minimum
- **Goal:** Deliver a versioned out-of-process extension path that cannot crash or indefinitely block the editor.
- **Architecture:** [Extension model](../docs/architecture/03-extension-model.md), [ADR-0002](../docs/architecture/decisions/0002-out-of-process-extensions.md)

## ZIT-145: Define the Extension-Minimum Exit Suite

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-108
- **Description:** Map every Milestone 3 outcome to protocol, lifecycle, contribution, SDK, crash, timeout, and compatibility evidence.
- **Acceptance criteria:**
  - [ ] The suite distinguishes public compatibility promises from implementation details.
  - [ ] Crash isolation, deadline, and cleanup failures block milestone exit.

## ZIT-146: Document the Version 1 Extension Threat Boundary

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-145
- **Description:** State what process isolation, environment restriction, permission declarations, and trusted local installation do and do not enforce.
- **Acceptance criteria:**
  - [ ] Documentation does not describe the extension process as a hostile-code sandbox.
  - [ ] The boundary informs protocol, UI wording, tests, and public security documentation.
