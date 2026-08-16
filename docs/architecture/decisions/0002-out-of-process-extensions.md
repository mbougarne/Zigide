# ADR-0002: Out-of-Process Extensions

* Status: Accepted
* Date: 2026-08-16

## Context

In-process plugins are fast and easy to call, but an extension crash or allocator error can terminate the IDE. A Zig ABI is also not an appropriate long-lived compatibility contract across compiler and package versions.

## Decision

Run executable extensions outside the main process and communicate through a versioned, framed protocol. Provide an official Zig SDK while keeping the wire contract language-neutral.

The initial model may launch one process per active extension. A shared host can be considered later only with measurements and without changing the public protocol.

## Consequences

* Crashes and memory ownership are isolated from the editor process.
* Extensions incur process, serialization, timeout, and lifecycle costs.
* The boundary is not a hostile-code sandbox; installed extensions retain the user's operating-system permissions.
* Extensions cannot import private IDE modules.

## Alternatives

* Dynamic libraries were rejected due to crash containment and ABI stability.
* WebAssembly was deferred because capability APIs, debugging, and runtime selection need a separate evidence-based design.
* VS Code API compatibility was rejected because it would import a very large behavioral contract and a JavaScript runtime requirement.

## Validation

Milestone 3 must demonstrate command and diagnostics extensions, cancellation, startup timeout, malformed messages, process crash isolation, and bounded restart.
