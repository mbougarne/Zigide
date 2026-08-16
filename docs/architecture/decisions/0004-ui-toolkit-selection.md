# ADR-0004: UI Toolkit Selection by Evidence

* Status: Proposed
* Date: 2026-08-16

## Context

An IDE UI needs high-quality text rendering, input methods, clipboard, accessibility, keyboard handling, multiple panels, and responsive rendering. Writing all of this from scratch would dominate the project. Choosing a web stack would accelerate UI work but weaken the goal of learning Zig and can add a large runtime. Choosing a young native Zig toolkit may expose missing IDE-grade capabilities.

## Proposed Decision

Keep the UI behind an adapter and select the first toolkit through a time-boxed macOS arm64 spike. Do not begin the production editor view before this ADR becomes accepted or is superseded.

The spike must implement:

* a window with explorer/editor/panel layout;
* rendering and scrolling of a large UTF-8 document;
* keyboard selection, clipboard, and Unicode input through an IME;
* font fallback, scale-factor changes, and accessible labels;
* a background search result delivered without blocking input;
* a distributable application bundle with measured startup time and memory.

## Candidates

Evaluate maintained native Zig libraries, direct platform adapters, and a lightweight webview approach. Record exact versions, licenses, maintenance health, binding complexity, and which required behaviors work. A custom GPU widget system is acceptable only if the project explicitly accepts its accessibility and text-input cost.

## Decision Criteria

Correct text input and recoverable editing outrank visual novelty. Then consider accessibility, Zig ownership, cross-platform path, dependency stability, debugging, packaging, performance, and implementation effort.

## Consequences

* Architecture can proceed without pretending an untested UI choice is settled.
* Milestone 0 includes throwaway work.
* The adapter boundary protects domain code but cannot eliminate toolkit-specific layout and accessibility work.

## Validation

Publish the spike code, measurements, screenshots, failures, and a scored comparison. Update this record with the accepted choice or supersede it.
