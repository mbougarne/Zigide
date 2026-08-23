# User, Extension, Security, and Contribution Documentation

- **Type:** Feature
- **Milestone:** 4 - Public Preview
- **Goal:** Publish verified instructions for users, extension authors, security reporters, and contributors.
- **Architecture:** [Extension model](../docs/architecture/03-extension-model.md), [Public development trace](../docs/architecture/04-data-safety-and-operations.md#public-development-trace)

## ZIT-197: Write the User Guide

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-108, ZIT-196
- **Description:** Document install, open/edit/save/recover, search, build, ZLS, settings, keybindings, logs, extensions, and removal.
- **Acceptance criteria:**
  - [ ] Every documented workflow is executed against the release candidate.
  - [ ] Recovery and durability claims match tested guarantees exactly.

## ZIT-198: Write the Extension Author Guide

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-182, ZIT-188
- **Description:** Document manifest, protocol, SDK, capabilities, permissions, examples, compatibility, limits, testing, and debugging.
- **Acceptance criteria:**
  - [ ] Examples validate against final schemas and supported fixtures.
  - [ ] The guide distinguishes protocol authority from SDK convenience.

## ZIT-199: Publish the Security Policy

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-146, ZIT-196
- **Description:** Document supported versions, private reporting, task trust, extension trust, data locations, logs, and non-sandboxed behavior.
- **Acceptance criteria:**
  - [ ] A real monitored private reporting path exists before publication.
  - [ ] Security wording distinguishes declaration, isolation, and enforced restriction.

## ZIT-200: Write the Contribution Guide

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-007, ZIT-189
- **Description:** Document setup, pinned toolchain, architecture/ADR rules, ticket workflow, tests, trace records, review, and licensing.
- **Acceptance criteria:**
  - [ ] A clean-clone walkthrough completes with only documented prerequisites.
  - [ ] The guide links the flat backlog and grouped work-package convention.

## ZIT-201: Write Troubleshooting and Data-Location Guides

- **Status:** Planned
- **Priority:** P1
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-130, ZIT-144, ZIT-168, ZIT-196
- **Description:** Document ZLS, tasks, recovery, extensions, diagnostics, logs, configuration reset, and all local data locations.
- **Acceptance criteria:**
  - [ ] Troubleshooting steps avoid destructive data removal by default.
  - [ ] Log-sharing guidance explains redaction and sensitive data risks.

## ZIT-202: Validate Documentation End to End

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-197, ZIT-198, ZIT-199, ZIT-200, ZIT-201
- **Description:** Run user, extension-author, security-reporting, and contributor walkthroughs and validate links, commands, schemas, screenshots, and claims.
- **Acceptance criteria:**
  - [ ] All local links and commands pass against the candidate.
  - [ ] Screenshots and records expose no personal or confidential data.
