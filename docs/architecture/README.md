# Zigide Architecture

## Status

This is the initial architecture baseline. It defines product boundaries and decision-making constraints before implementation begins. It is not a claim that the described components already exist.

## Documents

1. [Vision and scope](01-vision-and-scope.md)
2. [System architecture](02-system-architecture.md)
3. [Extension model](03-extension-model.md)
4. [Data, safety, and operations](04-data-safety-and-operations.md)
5. [Delivery roadmap](05-delivery-roadmap.md)
6. [Architecture decisions](decisions/README.md)

## Reading VS Code Correctly

Zigide studies the `VS Code codebase` for architectural lessons. The most useful boundaries are:

* `src/vs/base`: lifecycle, events, and low-level utilities.
* `src/vs/platform`: reusable services and registries.
* `src/vs/editor`: text model and language features.
* `src/vs/workbench`: application composition and user-facing features.
* `src/vs/workbench/services/extensions`: extension-host lifecycle and RPC.

Zigide adopts the principles of explicit layers, services, declarative contributions, lazy activation, and process boundaries. It does not reproduce VS Code's scale, TypeScript APIs, UI, compatibility surface, or internal implementation.

Code - OSS is MIT licensed. Architectural ideas are not copied code. If implementation later copies or adapts a substantial code fragment, contributors must verify its license and preserve required notices.

## Decision Policy

* Accepted ADRs are binding until superseded.
* Proposed ADRs invite a focused spike or discussion and are not implementation mandates.
* Major changes to process boundaries, persistence formats, extension compatibility, or UI strategy require an ADR.
* Documentation must separate current facts, accepted decisions, and future intent.
