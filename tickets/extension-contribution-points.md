# Extension Contribution Points

- **Type:** Feature
- **Milestone:** 3 - Extension Minimum
- **Goal:** Route the approved version 1 contributions through existing application services with owner cleanup.
- **Architecture:** [Initial contribution points](../docs/architecture/03-extension-model.md#initial-contribution-points), [Command flow](../docs/architecture/02-system-architecture.md#command-flow)

## ZIT-169: Implement Extension-Owned Registrations

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-017, ZIT-159, ZIT-164
- **Description:** Associate every contribution registration and resource with one extension owner and disposable lifetime.
- **Acceptance criteria:**
  - [ ] Owner stop/failure removes only its registrations.
  - [ ] Stale contribution handles cannot invoke disposed extension state.

## ZIT-170: Implement Command and Default-Keybinding Contributions

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-074, ZIT-104, ZIT-163, ZIT-169
- **Description:** Index commands/keybindings declaratively and activate the owner lazily when a contributed command executes.
- **Acceptance criteria:**
  - [ ] Contribution discovery does not launch the extension.
  - [ ] Invocation validates arguments, enablement, owner state, and deadline.

## ZIT-171: Implement Language-Metadata Contributions

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-159, ZIT-169
- **Description:** Register version 1 language IDs, extensions, filenames, and approved metadata without arbitrary code execution.
- **Acceptance criteria:**
  - [ ] Conflicts and invalid patterns resolve deterministically.
  - [ ] Unsupported grammar, theme, or UI metadata is rejected.

## ZIT-172: Implement Task-Provider Contributions

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-116, ZIT-164, ZIT-169
- **Description:** Request bounded task definitions from activated providers and pass approved tasks through existing trust/process services.
- **Acceptance criteria:**
  - [ ] Extension tasks still require user trust and avoid shell interpolation.
  - [ ] Invalid or late task definitions cannot execute.

## ZIT-173: Implement Read-Only Document Access

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-047, ZIT-152, ZIT-164
- **Description:** Expose bounded, granted document identity, version, and text reads without a version 1 edit capability.
- **Acceptance criteria:**
  - [ ] Ungranted, closed, stale, and oversized reads fail explicitly.
  - [ ] No protocol method can mutate document text through this capability.

## ZIT-174: Implement Diagnostic Contributions

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-139, ZIT-140, ZIT-164, ZIT-169
- **Description:** Validate extension-owned diagnostic sets and route them through the diagnostic service.
- **Acceptance criteria:**
  - [ ] Paths, versions, ranges, messages, counts, and sizes are bounded and validated.
  - [ ] Owner cleanup removes contributed diagnostics.

## ZIT-175: Implement Notification and Output Contributions

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-141, ZIT-164, ZIT-166, ZIT-169
- **Description:** Expose bounded notifications and owner-labelled output channels without arbitrary UI injection.
- **Acceptance criteria:**
  - [ ] Floods, oversized payloads, and invalid severity values are limited.
  - [ ] Notifications identify the source and remain accessible.

## ZIT-176: Verify Contribution Cleanup and Denials

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 3-5 days
- **Dependencies:** ZIT-170, ZIT-171, ZIT-172, ZIT-173, ZIT-174, ZIT-175
- **Description:** Test multiple owners, activation, stop, crash, denied grants, malformed payloads, and explicitly unsupported contribution types.
- **Acceptance criteria:**
  - [ ] One owner's failure leaves all other contributions functional.
  - [ ] Menus, themes, custom views, webviews, debuggers, and arbitrary UI injection remain rejected.
