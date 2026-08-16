# Vision and Scope

## Purpose

Zigide is a small, useful, extensible IDE whose core is written in Zig. It has three equally important outcomes:

1. Produce an IDE that people can use for real work.
2. Create a public, auditable case study of human-AI software development.
3. Teach Zig, IDE internals, AI concepts, and architecture through the repository's history.

Success is not measured by matching VS Code feature for feature. It is measured by a coherent product, understandable code, verified behavior, and honest records of how decisions were made.

## Product Principles

* **Useful before broad:** finish a dependable edit-build-diagnose loop for Zig before adding many languages or surfaces.
* **Zig owns the product:** core domain logic, application services, protocol clients, and official extension tooling are implemented in Zig. Operating-system and C-library integration is allowed at explicit adapter boundaries.
* **Extensible by contract:** commands, language features, and later UI contributions use versioned public contracts rather than internal imports.
* **Local first:** the initial product works without an account, cloud service, telemetry service, or remote workspace.
* **Recoverable:** user edits and settings survive expected crashes and interrupted writes.
* **Inspectable:** architecture decisions, substantial AI interactions, and verification evidence live in the repository.
* **Honest:** educational AI records explain concepts without claiming access to private model internals.

## Initial User Journey

A user can:

1. Open a local folder.
2. Browse files and open multiple text documents.
3. Edit, undo, redo, save, and recover unsaved work.
4. Search files and text in the workspace.
5. run `zig build`, see structured output, and navigate to diagnostics.
6. Use ZLS-backed completion, hover, definitions, references, formatting, and diagnostics.
7. Configure settings and keybindings.
8. Install and run a trusted local extension through a documented protocol.

## First Release Scope

The first release targets local Zig development on macOS arm64. Its core surfaces are:

* Window, command palette, editor area, file explorer, problems view, output view, and integrated task terminal or process output.
* UTF-8 text documents with explicit handling for invalid input and line-ending preservation.
* Workspace, file, configuration, command, keybinding, search, task, language-client, storage, logging, and extension services.
* ZLS over Language Server Protocol (LSP).
* A declarative extension manifest and an out-of-process protocol.

## Explicit Non-Goals for the First Release

* VS Code extension compatibility.
* Remote development, collaboration, settings sync, accounts, or a marketplace.
* Debug Adapter Protocol UI.
* Notebook, webview, custom editor, or embedded browser support.
* Untrusted extension sandboxing strong enough for hostile code.
* A complete terminal emulator written from scratch.
* Multi-window or distributed workspace state.
* Feature parity across macOS, Linux, and Windows.
* Training a foundation model or exposing genuine proprietary model telemetry.

## Quality Gates

A milestone is complete only when its user journey works, relevant tests pass, failure modes are documented, and trace records identify what was and was not verified. Demonstrations are useful evidence, but they do not replace automated checks.
