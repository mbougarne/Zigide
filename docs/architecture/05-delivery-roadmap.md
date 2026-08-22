# Delivery Roadmap

The roadmap builds a vertical user journey before broadening features. Dates are intentionally absent until implementation estimates have evidence.

## Milestone 0: Foundations and Spikes

Deliverables:

* Zig build, module layout, formatter, test command, and CI.
* A pinned Zig toolchain version recorded in the repository, plus an upgrade policy. Zig changes incompatibly between minor releases, so builds must name the exact version they were verified against, and toolchain upgrades are deliberate reviewed changes rather than silent drift.
* Headless application composition with logging, commands, and deterministic shutdown.
* UI toolkit spike using the criteria in ADR-0004.
* Text-model benchmark and property-test harness.
* ZLS process and framing spike.

Exit evidence:

* One documented build/test path works on macOS arm64 with the pinned Zig version.
* ADR-0004 is accepted or replaced.
* Protocol decoder handles split, combined, malformed, oversized, and cancelled messages.

## Milestone 1: Dependable Editor

Deliverables:

* Window, editor, file explorer, command palette, and status surface.
* Open, edit, selection, undo/redo, save, save-as, and external-change handling.
* Atomic settings and recovery snapshots.
* Keyboard, mouse, clipboard, Unicode input, and accessibility baseline.

Exit evidence:

* A user can edit a real Zig project without data loss in tested crash scenarios.
* Large-file and sustained-edit budgets are defined and measured.

## Milestone 2: Zig Work Loop

Deliverables:

* Workspace search and file watching.
* `zig build` tasks with cancellation and structured output.
* ZLS completion, hover, definition, references, formatting, symbols, and diagnostics.
* Problems and output views.

Exit evidence:

* A sample Zig project can be navigated, changed, built, and diagnosed entirely in Zigide.
* ZLS crashes do not terminate the IDE and recovery is visible.

## Milestone 3: Extension Minimum

Deliverables:

* Manifest JSON Schema and validator.
* Discovery, activation, protocol handshake, permissions display, and bounded restart.
* Zig SDK and example command/diagnostics extensions.
* Compatibility and malformed-extension test suites.

Exit evidence:

* An extension can add a command and diagnostics without linking against IDE internals.
* A crashing or non-responsive extension cannot crash or indefinitely block the editor.

## Milestone 4: Public Preview

Deliverables:

* Signed or checksummed macOS arm64 artifact and reproducible packaging instructions.
* User documentation, extension author guide, security policy, and contribution guide.
* Performance pass, accessibility review, migration policy, and issue templates.
* Audit of public AI trace records and third-party notices.

Exit evidence:

* A new user can install, open a project, complete the Zig work loop, and report a useful failure.
* Known limitations and unsupported security assumptions are public.

## Deferred Tracks

After the preview, prioritize from measured use: debugger support through DAP, Linux and Windows adapters, themes, richer extension contributions, terminal emulation, remote workspaces, and marketplace infrastructure.

Each track begins with a user problem and an ADR. VS Code having a feature is not sufficient justification.
