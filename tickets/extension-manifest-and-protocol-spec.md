# Extension Manifest and Protocol Specification

- **Type:** Feature
- **Milestone:** 3 - Extension Minimum
- **Goal:** Freeze the smallest public manifest and JSON-RPC protocol before extension code is accepted.
- **Architecture:** [Extension package](../docs/architecture/03-extension-model.md#package), [Extension protocol](../docs/architecture/03-extension-model.md#protocol), [ADR-0003](../docs/architecture/decisions/0003-open-versioned-protocols.md)

## ZIT-147: Resolve Protocol Version Representation in an ADR

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-026, ZIT-146
- **Description:** Choose one manifest/handshake representation for protocol major and minor versions and record compatibility rules and rejected alternatives.
- **Acceptance criteria:**
  - [ ] An accepted ADR resolves the current string-versus-fields ambiguity.
  - [ ] Major incompatibility and minor optional-capability behavior are explicit.

## ZIT-148: Define the Extension Manifest Schema

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-147
- **Description:** Specify identity, package version, display metadata, protocol version, entrypoint, activation events, contributions, and permissions in JSON Schema.
- **Acceptance criteria:**
  - [ ] Minimum, complete, invalid, and forward-compatible fixtures validate as documented.
  - [ ] IDs, versions, arrays, fields, and sizes have explicit constraints.

## ZIT-149: Specify Package Paths and Platform Executables

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-148
- **Description:** Define package-root containment, normalization, symlink behavior, executable selection, and macOS arm64 entrypoint rules.
- **Acceptance criteria:**
  - [ ] Absolute, traversal, missing, non-executable, and escaping paths are rejected.
  - [ ] Other platforms can be added later without changing version 1 semantics silently.

## ZIT-150: Specify Initialization and Capability Negotiation

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-3 days
- **Dependencies:** ZIT-147, ZIT-148
- **Description:** Define initialize/initialized payloads, IDE/extension identity, declared/granted capabilities, workspace roots, and limits.
- **Acceptance criteria:**
  - [ ] Unsupported required capabilities fail initialization clearly.
  - [ ] Unknown optional fields follow the ADR compatibility policy.

## ZIT-151: Specify Version 1 RPC Methods and Errors

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-150
- **Description:** Define command, task, document, diagnostic, notification, output, cancellation, shutdown, and error message contracts.
- **Acceptance criteria:**
  - [ ] Each request has result, error, cancellation, deadline, and invalid-parameter behavior.
  - [ ] Method schemas expose no private Zigide types.

## ZIT-152: Specify Permissions and Grants

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-146, ZIT-150, ZIT-151
- **Description:** Define declared permissions, runtime grants, user-visible wording, and the limits of enforcement.
- **Acceptance criteria:**
  - [ ] Read-only document and workspace-root grants are explicit.
  - [ ] Permission text separates declaration from operating-system enforcement.

## ZIT-153: Specify Protocol Resource Limits and Deadlines

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 1-2 days
- **Dependencies:** ZIT-150, ZIT-151
- **Description:** Set message, log, startup, request, cancellation, and shutdown limits with standard error behavior.
- **Acceptance criteria:**
  - [ ] Limits are part of initialization or fixed versioned defaults.
  - [ ] Exceeding a limit has deterministic failure and cleanup semantics.

## ZIT-154: Publish Protocol Fixtures and Compatibility Matrix

- **Status:** Planned
- **Priority:** P0
- **Estimate:** 2-4 days
- **Dependencies:** ZIT-148, ZIT-149, ZIT-150, ZIT-151, ZIT-152, ZIT-153
- **Description:** Publish valid/invalid manifests, handshakes, method payloads, errors, and version combinations as reviewed public fixtures.
- **Acceptance criteria:**
  - [ ] Every public schema has positive and negative fixtures.
  - [ ] The matrix states exactly which version combinations are supported.
