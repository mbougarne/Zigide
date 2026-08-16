# ADR-0003: Open, Versioned External Protocols

* Status: Accepted
* Date: 2026-08-16

## Context

Language intelligence, debugging, and extensions cross process boundaries. Private ad hoc messages would make interoperability, testing, and evolution difficult.

## Decision

Use established open protocols where they fit:

* LSP for language features.
* DAP for later debugger integration.
* JSON-RPC 2.0 semantics and `Content-Length` framing for Zigide's extension protocol.

Zigide-specific protocols declare major and minor versions, capabilities, size limits, cancellation behavior, error codes, and compatibility fixtures.

## Consequences

* Existing servers and protocol knowledge can be reused.
* JSON is inspectable but less compact and less type-safe than an in-process Zig call.
* Protocol types must be validated at runtime.
* LSP quirks remain isolated in the language adapter rather than leaking into the text model.

## Alternatives

* A custom binary protocol was rejected until profiling proves JSON framing inadequate.
* Unversioned messages were rejected because public extension compatibility requires explicit evolution.

## Validation

Fuzz framing and message decoding. Run integration fixtures across every supported protocol version and at least one real ZLS process.
