# Zigide Backlog

This is the canonical flat index of every Zigide ticket. Each entry links to its full details in the owning feature or epic file.

## Milestone 0: Foundations and Spikes

### [Foundations and Spikes](foundations-and-spikes.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-001](foundations-and-spikes.md#zit-001-define-milestone-0-exit-checklist) | Define Milestone 0 Exit Checklist | Turn every Milestone 0 exit condition into an evidence checklist with an owner ticket and exact verification command or artifact. |
| [ZIT-002](foundations-and-spikes.md#zit-002-publish-milestone-0-evidence-report) | Publish Milestone 0 Evidence Report | Consolidate exact tool versions, checks, measurements, failures, and resolved decisions into the Milestone 0 completion report. |

### [Application Module Layout](application-module-layout.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-003](application-module-layout.md#zit-003-create-product-source-and-test-directories) | Create Product Source and Test Directories | Add the initial product and test directory structure without speculative implementation files. |
| [ZIT-004](application-module-layout.md#zit-004-declare-product-library-modules) | Declare Product Library Modules | Define the reusable Zig modules and their legal import directions in `build.zig`. |
| [ZIT-005](application-module-layout.md#zit-005-add-the-zigide-executable-target) | Add the Zigide Executable Target | Add a minimal executable and composition root that starts and exits deterministically. |
| [ZIT-006](application-module-layout.md#zit-006-add-product-unit-and-integration-test-targets) | Add Product Unit and Integration Test Targets | Create product-focused unit and integration test roots and wire them into the build. |
| [ZIT-007](application-module-layout.md#zit-007-enforce-module-dependency-boundaries) | Enforce Module Dependency Boundaries | Add a maintainable check or build-graph test that prevents forbidden inward-dependency violations. |

### [Foundation Primitives](foundation-primitives.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-008](foundation-primitives.md#zit-008-implement-typed-ids-and-injectable-clocks) | Implement Typed IDs and Injectable Clocks | Provide typed operation/correlation IDs and production/test clocks with deterministic substitutes. |
| [ZIT-009](foundation-primitives.md#zit-009-implement-cooperative-cancellation) | Implement Cooperative Cancellation | Define cancellation ownership, idempotent signalling, observation, and cleanup for background work. |
| [ZIT-010](foundation-primitives.md#zit-010-implement-scoped-events-and-subscriptions) | Implement Scoped Events and Subscriptions | Add typed events whose subscriptions return explicit disposable handles. |
| [ZIT-011](foundation-primitives.md#zit-011-define-contextual-application-errors) | Define Contextual Application Errors | Establish error categories and context propagation without hiding Zig error unions behind an exception framework. |
| [ZIT-012](foundation-primitives.md#zit-012-define-structured-logging-contracts) | Define Structured Logging Contracts | Define structured log events and a replaceable sink interface for application and test use. |
| [ZIT-013](foundation-primitives.md#zit-013-verify-foundation-allocation-and-lifetime-rules) | Verify Foundation Allocation and Lifetime Rules | Document allocator ownership and test success, failure, disposal, and cancellation paths with Zig's test allocator. |

### [Headless Application and Commands](headless-application-and-commands.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-014](headless-application-and-commands.md#zit-014-define-application-service-composition) | Define Application Service Composition | Define the composition context that wires explicit services and ports without a general dependency-injection container. |
| [ZIT-015](headless-application-and-commands.md#zit-015-implement-command-registration-and-lookup) | Implement Command Registration and Lookup | Register stable namespaced command IDs and resolve handlers without UI ownership. |
| [ZIT-016](headless-application-and-commands.md#zit-016-validate-command-arguments-and-preconditions) | Validate Command Arguments and Preconditions | Validate typed command arguments and enablement preconditions before invoking handlers. |
| [ZIT-017](headless-application-and-commands.md#zit-017-implement-command-registration-lifetimes) | Implement Command Registration Lifetimes | Make command ownership disposable so services and future extensions can unregister cleanly. |
| [ZIT-018](headless-application-and-commands.md#zit-018-implement-deterministic-startup-and-shutdown) | Implement Deterministic Startup and Shutdown | Implement ordered, idempotent application startup and shutdown with deadlines for future workers and child processes. |
| [ZIT-019](headless-application-and-commands.md#zit-019-build-headless-port-test-doubles) | Build Headless Port Test Doubles | Provide deterministic fake file, storage, clock, process, and UI-scheduling ports for behavioral tests. |

### [Protocol Framing and ZLS Spike](protocol-framing-and-zls-spike.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-020](protocol-framing-and-zls-spike.md#zit-020-implement-incremental-content-length-decoding) | Implement Incremental Content-Length Decoding | Decode complete `Content-Length` frames from arbitrary byte chunks without assuming read boundaries. |
| [ZIT-021](protocol-framing-and-zls-spike.md#zit-021-implement-framing-encoder-and-size-limits) | Implement Framing Encoder and Size Limits | Encode framed JSON payloads and reject advertised or actual payloads above configured limits. |
| [ZIT-022](protocol-framing-and-zls-spike.md#zit-022-implement-json-rpc-correlation-prototype) | Implement JSON-RPC Correlation Prototype | Correlate JSON-RPC requests, responses, notifications, and errors over the framed transport. |
| [ZIT-023](protocol-framing-and-zls-spike.md#zit-023-prototype-protocol-cancellation-and-deadlines) | Prototype Protocol Cancellation and Deadlines | Propagate cancellation and request deadlines through the prototype without applying late results. |
| [ZIT-024](protocol-framing-and-zls-spike.md#zit-024-implement-child-process-standard-io-transport) | Implement Child-Process Standard-I/O Transport | Spawn a child executable with argument arrays and transport framed messages over standard input/output. |
| [ZIT-025](protocol-framing-and-zls-spike.md#zit-025-complete-a-real-zls-initialization-fixture) | Complete a Real ZLS Initialization Fixture | Initialize and cleanly stop a recorded ZLS version against a temporary Zig workspace. |
| [ZIT-026](protocol-framing-and-zls-spike.md#zit-026-fuzz-and-stress-the-framing-prototype) | Fuzz and Stress the Framing Prototype | Fuzz framing and dispatch with malformed, fragmented, combined, oversized, and cancelled message streams. |

### [Text Model Spike](text-model-spike.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-027](text-model-spike.md#zit-027-define-text-model-reference-behavior) | Define Text-Model Reference Behavior | Implement a simple reference string model and define valid edit, position, line-ending, and invalid-input semantics for the spike. |
| [ZIT-028](text-model-spike.md#zit-028-prototype-piece-table-storage) | Prototype Piece-Table Storage | Prototype original/add buffers and piece operations for insert, delete, replace, and snapshot reads. |
| [ZIT-029](text-model-spike.md#zit-029-prototype-the-line-start-index) | Prototype the Line-Start Index | Add offset-to-line/column and line/column-to-offset lookup that updates after edits. |
| [ZIT-030](text-model-spike.md#zit-030-add-randomized-edit-equivalence-tests) | Add Randomized Edit Equivalence Tests | Generate valid edit sequences and compare piece-table content and positions with the reference model after each step. |
| [ZIT-031](text-model-spike.md#zit-031-define-representative-text-workloads) | Define Representative Text Workloads | Define small, medium, large, long-line, UTF-8, and sustained-edit fixtures and operation distributions. |
| [ZIT-032](text-model-spike.md#zit-032-benchmark-text-storage-and-line-lookup) | Benchmark Text Storage and Line Lookup | Measure open, insert, delete, snapshot, lookup, memory, and sustained-edit behavior against the baseline. |
| [ZIT-033](text-model-spike.md#zit-033-publish-text-model-recommendation) | Publish Text-Model Recommendation | Recommend piece table, tree-backed variant, rope, or another structure using correctness and benchmark evidence. |

### [UI Toolkit Spike](ui-toolkit-spike.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-034](ui-toolkit-spike.md#zit-034-build-the-shared-ui-spike-scenario) | Build the Shared UI Spike Scenario | Define the same explorer/editor/panel scenario, document fixture, background result, measurements, and scoring weights for all candidates. |
| [ZIT-035](ui-toolkit-spike.md#zit-035-spike-direct-appkit-integration) | Spike Direct AppKit Integration | Implement the shared scenario through Zig-to-AppKit integration and record binding and platform costs. |
| [ZIT-036](ui-toolkit-spike.md#zit-036-spike-the-strongest-native-zig-toolkit) | Spike the Strongest Native Zig Toolkit | Select the best-maintained candidate among the documented native Zig options and implement the shared scenario. |
| [ZIT-037](ui-toolkit-spike.md#zit-037-spike-the-system-webview-option) | Spike the System WebView Option | Implement the shared scenario with WKWebView without bundling a browser runtime and measure the non-Zig surface. |
| [ZIT-038](ui-toolkit-spike.md#zit-038-verify-clipboard-and-ime-behavior) | Verify Clipboard and IME Behavior | Test multiline Unicode clipboard and marked-text IME update, commit, and cancellation on the target Mac. |
| [ZIT-039](ui-toolkit-spike.md#zit-039-verify-ui-accessibility-behavior) | Verify UI Accessibility Behavior | Test labels, focus order, text exposure, selection reporting, and basic editing with VoiceOver. |
| [ZIT-040](ui-toolkit-spike.md#zit-040-measure-ui-performance-and-packaging) | Measure UI Performance and Packaging | Measure startup, idle memory, large-document scrolling, background-result responsiveness, package size, and bundling complexity. |
| [ZIT-041](ui-toolkit-spike.md#zit-041-score-candidates-and-resolve-adr-0004) | Score Candidates and Resolve ADR-0004 | Publish the scored comparison and accept, reject, or supersede ADR-0004 with the selected production UI strategy. |

## Milestone 1: Dependable Editor

### [Dependable Editor](dependable-editor.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-042](dependable-editor.md#zit-042-define-the-dependable-editor-exit-suite) | Define the Dependable-Editor Exit Suite | Map Milestone 1 outcomes to automated domain, integration, crash, UI, accessibility, and performance evidence. |
| [ZIT-043](dependable-editor.md#zit-043-verify-the-end-to-end-editing-journey) | Verify the End-to-End Editing Journey | Exercise project open, multi-file editing, undo/redo, save, conflict handling, settings, recovery, and keyboard-accessible navigation in one release-like flow. |

### [Production Text Model](production-text-model.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-044](production-text-model.md#zit-044-implement-production-text-storage) | Implement Production Text Storage | Implement the selected original/add buffer, piece tree, rope, or other approved production storage with explicit ownership. |
| [ZIT-045](production-text-model.md#zit-045-implement-positions-and-ranges) | Implement Positions and Ranges | Define zero-based offsets, positions, normalized ranges, comparison, and validation independent of UI or LSP types. |
| [ZIT-046](production-text-model.md#zit-046-implement-atomic-edit-batches-and-versions) | Implement Atomic Edit Batches and Versions | Validate and apply all-or-nothing edit batches and increment document versions only after successful mutation. |
| [ZIT-047](production-text-model.md#zit-047-implement-stable-text-snapshots) | Implement Stable Text Snapshots | Provide immutable snapshots suitable for background work with a documented lifetime and allocation policy. |
| [ZIT-048](production-text-model.md#zit-048-implement-the-production-line-index) | Implement the Production Line Index | Maintain line starts and bounded offset/position lookup across edit batches. |
| [ZIT-049](production-text-model.md#zit-049-preserve-encoding-and-line-ending-metadata) | Preserve Encoding and Line-Ending Metadata | Track decoding status, line-ending form, and final-newline state without silently normalizing user data. |
| [ZIT-050](production-text-model.md#zit-050-property-test-the-production-text-model) | Property-Test the Production Text Model | Compare generated production operations with the reference model and retain reproducible regression seeds. |
| [ZIT-051](production-text-model.md#zit-051-verify-production-text-budgets) | Verify Production Text Budgets | Rerun approved workloads and verify or revise large-file, sustained-edit, lookup, and memory budgets. |

### [Document and Workspace Lifecycle](document-and-workspace-lifecycle.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-052](document-and-workspace-lifecycle.md#zit-052-define-local-resource-identity) | Define Local Resource Identity | Define normalized resource paths, equality, case behavior, and symlink policy for the macOS target. |
| [ZIT-053](document-and-workspace-lifecycle.md#zit-053-implement-single-folder-workspace-open-and-close) | Implement Single-Folder Workspace Open and Close | Create and dispose one local folder workspace without native-dialog dependencies in domain code. |
| [ZIT-054](document-and-workspace-lifecycle.md#zit-054-implement-the-open-document-registry) | Implement the Open-Document Registry | Track multiple open text documents without duplicating normalized resources. |
| [ZIT-055](document-and-workspace-lifecycle.md#zit-055-track-active-and-dirty-document-state) | Track Active and Dirty Document State | Track active document and whether each document diverges from its last acknowledged save state. |
| [ZIT-056](document-and-workspace-lifecycle.md#zit-056-implement-dirty-document-close-decisions) | Implement Dirty-Document Close Decisions | Request save, discard, or cancel decisions through a UI-neutral contract before close, workspace switch, or shutdown. |
| [ZIT-057](document-and-workspace-lifecycle.md#zit-057-reject-stale-workspace-and-document-results) | Reject Stale Workspace and Document Results | Attach operation and document/workspace versions to background results and discard stale outcomes on the application thread. |

### [Selection, Undo, and Redo](selection-undo-and-redo.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-058](selection-undo-and-redo.md#zit-058-implement-selection-state) | Implement Selection State | Represent anchor, active position, direction, and normalized selected range. |
| [ZIT-059](selection-undo-and-redo.md#zit-059-define-edit-transactions) | Define Edit Transactions | Group edits with before/after selections and command metadata into reversible transactions. |
| [ZIT-060](selection-undo-and-redo.md#zit-060-implement-undo) | Implement Undo | Reverse committed transactions in strict history order and restore prior selections. |
| [ZIT-061](selection-undo-and-redo.md#zit-061-implement-redo-and-branching) | Implement Redo and Branching | Reapply undone transactions and define redo-history behavior after a new edit branch. |
| [ZIT-062](selection-undo-and-redo.md#zit-062-implement-typing-coalescence-rules) | Implement Typing Coalescence Rules | Coalesce compatible typing/deletion actions while preserving explicit command and focus boundaries. |
| [ZIT-063](selection-undo-and-redo.md#zit-063-bound-and-property-test-edit-history) | Bound and Property-Test Edit History | Enforce a documented memory policy and property-test random edit/undo/redo sequences. |

### [Safe File I/O](safe-file-io.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-064](safe-file-io.md#zit-064-implement-bounded-file-reads) | Implement Bounded File Reads | Read local files under explicit size limits and capture stable metadata for later conflict checks. |
| [ZIT-065](safe-file-io.md#zit-065-implement-text-decoding-policy) | Implement Text Decoding Policy | Detect UTF-8 validity and apply the approved invalid-input policy without implicit replacement. |
| [ZIT-066](safe-file-io.md#zit-066-implement-atomic-save-replacement) | Implement Atomic Save Replacement | Write a complete temporary replacement, sync according to documented guarantees, and atomically rename it over the destination. |
| [ZIT-067](safe-file-io.md#zit-067-implement-save-as-and-permission-handling) | Implement Save As and Permission Handling | Save to a new resource identity and preserve or set permissions according to a documented macOS policy. |
| [ZIT-068](safe-file-io.md#zit-068-capture-and-compare-external-file-metadata) | Capture and Compare External File Metadata | Compare stable base metadata before save and detect external modifications or replacement. |
| [ZIT-069](safe-file-io.md#zit-069-implement-external-change-resolution-flow) | Implement External-Change Resolution Flow | Request reload, inspect, overwrite, or cancel decisions without silently resolving disk divergence. |
| [ZIT-070](safe-file-io.md#zit-070-fault-test-file-open-and-save) | Fault-Test File Open and Save | Exercise temporary filesystems, permission failures, partial writes, rename failures, disk changes, and line-ending round trips. |

### [Configuration and Keybindings](configuration-and-keybindings.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-071](configuration-and-keybindings.md#zit-071-define-core-setting-descriptors-and-defaults) | Define Core Setting Descriptors and Defaults | Define setting keys, types, defaults, scope, and validation for first-release behavior. |
| [ZIT-072](configuration-and-keybindings.md#zit-072-implement-configuration-layer-merging) | Implement Configuration Layer Merging | Merge defaults, user settings, and workspace settings using documented precedence. |
| [ZIT-073](configuration-and-keybindings.md#zit-073-parse-settings-with-partial-diagnostics) | Parse Settings with Partial Diagnostics | Parse JSON settings and report unknown or invalid entries without discarding valid siblings. |
| [ZIT-074](configuration-and-keybindings.md#zit-074-parse-and-resolve-keybindings) | Parse and Resolve Keybindings | Parse key chords and resolve conflicts deterministically against command preconditions. |
| [ZIT-075](configuration-and-keybindings.md#zit-075-persist-and-watch-configuration-atomically) | Persist and Watch Configuration Atomically | Atomically update editable settings/keybinding files and apply valid external changes on the application thread. |
| [ZIT-076](configuration-and-keybindings.md#zit-076-expose-configuration-and-keybinding-commands) | Expose Configuration and Keybinding Commands | Add commands to inspect effective settings, conflicts, and editable configuration resources without embedding UI policy. |

### [Crash Recovery](crash-recovery.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-077](crash-recovery.md#zit-077-define-the-recovery-format) | Define the Recovery Format | Define a versioned recovery manifest and snapshot format containing resource, base metadata, document version, encoding, line ending, and checksum. |
| [ZIT-078](crash-recovery.md#zit-078-implement-atomic-recovery-snapshot-writes) | Implement Atomic Recovery Snapshot Writes | Write complete snapshots outside the workspace using interruption-safe replacement. |
| [ZIT-079](crash-recovery.md#zit-079-schedule-bounded-recovery-snapshots) | Schedule Bounded Recovery Snapshots | Snapshot dirty documents on a bounded cadence and focus loss without blocking editor input. |
| [ZIT-080](crash-recovery.md#zit-080-discover-recoverable-sessions-at-startup) | Discover Recoverable Sessions at Startup | Enumerate and validate recovery manifests during startup without opening or overwriting workspace files. |
| [ZIT-081](crash-recovery.md#zit-081-implement-recovery-divergence-decisions) | Implement Recovery Divergence Decisions | Compare snapshot base metadata with disk and request restore, inspect, or discard decisions when state diverges. |
| [ZIT-082](crash-recovery.md#zit-082-clean-up-resolved-recovery-data) | Clean Up Resolved Recovery Data | Remove only matching snapshots after verified save or explicit discard and prune safe orphan data. |
| [ZIT-083](crash-recovery.md#zit-083-crash-test-recovery-guarantees) | Crash-Test Recovery Guarantees | Terminate the process at representative snapshot stages and verify recovery within the documented cadence. |

### [macOS Application Shell](macos-application-shell.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-084](macos-application-shell.md#zit-084-implement-macos-application-lifecycle) | Implement macOS Application Lifecycle | Connect native application launch, activation, reopen, and termination requests to the application lifecycle. |
| [ZIT-085](macos-application-shell.md#zit-085-implement-the-main-window-and-layout) | Implement the Main Window and Layout | Create stable explorer, editor, bottom-panel, and status regions with responsive constraints. |
| [ZIT-086](macos-application-shell.md#zit-086-implement-ui-scheduling-to-the-application-thread) | Implement UI Scheduling to the Application Thread | Marshal native events and background results to the single mutable-state owner. |
| [ZIT-087](macos-application-shell.md#zit-087-establish-shell-focus-and-accessibility-regions) | Establish Shell Focus and Accessibility Regions | Expose accessible region names and a predictable keyboard focus order for the shell. |
| [ZIT-088](macos-application-shell.md#zit-088-present-startup-and-fatal-initialization-errors) | Present Startup and Fatal Initialization Errors | Show actionable initialization errors without crashing silently or exposing sensitive internals. |
| [ZIT-089](macos-application-shell.md#zit-089-verify-shell-lifecycle-and-packaging-smoke-tests) | Verify Shell Lifecycle and Packaging Smoke Tests | Exercise launch, resize, focus, close, reopen, failure, and app-bundle smoke paths on the target Mac. |

### [Editor Input, Rendering, and Accessibility](editor-input-rendering-and-accessibility.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-090](editor-input-rendering-and-accessibility.md#zit-090-implement-viewport-text-rendering) | Implement Viewport Text Rendering | Render only visible lines plus bounded overscan from stable text snapshots. |
| [ZIT-091](editor-input-rendering-and-accessibility.md#zit-091-implement-text-measurement-and-font-fallback) | Implement Text Measurement and Font Fallback | Measure glyph runs, line heights, tabs, and fallback fonts through the chosen UI adapter. |
| [ZIT-092](editor-input-rendering-and-accessibility.md#zit-092-map-screen-coordinates-and-text-positions) | Map Screen Coordinates and Text Positions | Convert viewport coordinates to validated text positions and positions back to caret geometry. |
| [ZIT-093](editor-input-rendering-and-accessibility.md#zit-093-render-carets-and-selections) | Render Carets and Selections | Draw active/inactive caret and selected ranges without mutating selection state in the renderer. |
| [ZIT-094](editor-input-rendering-and-accessibility.md#zit-094-implement-keyboard-editing-commands) | Implement Keyboard Editing Commands | Route navigation, insertion, deletion, selection, undo, redo, save, and command shortcuts through commands and transactions. |
| [ZIT-095](editor-input-rendering-and-accessibility.md#zit-095-implement-mouse-selection-and-scrolling) | Implement Mouse Selection and Scrolling | Handle click, shift-click, drag selection, wheel/trackpad scrolling, and autoscroll at viewport edges. |
| [ZIT-096](editor-input-rendering-and-accessibility.md#zit-096-implement-clipboard-operations) | Implement Clipboard Operations | Implement copy, cut, and paste through a platform clipboard port with bounded text input. |
| [ZIT-097](editor-input-rendering-and-accessibility.md#zit-097-implement-ime-composition) | Implement IME Composition | Handle marked-text update, replacement, commit, and cancellation without corrupting content or undo history. |
| [ZIT-098](editor-input-rendering-and-accessibility.md#zit-098-expose-editor-accessibility-semantics) | Expose Editor Accessibility Semantics | Expose editor text, caret, selection, visible range, and editing actions to macOS accessibility APIs. |
| [ZIT-099](editor-input-rendering-and-accessibility.md#zit-099-verify-editor-latency-input-and-accessibility) | Verify Editor Latency, Input, and Accessibility | Run automated and target-device checks for rendering, typing, scrolling, clipboard, IME, scaling, keyboard, and VoiceOver behavior. |

### [Explorer, Command Palette, and Status](explorer-command-palette-and-status.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-100](explorer-command-palette-and-status.md#zit-100-implement-the-explorer-tree-model) | Implement the Explorer Tree Model | Load one workspace tree lazily or in bounded batches and represent loading, empty, and error states. |
| [ZIT-101](explorer-command-palette-and-status.md#zit-101-enforce-explorer-path-boundaries) | Enforce Explorer Path Boundaries | Apply normalized path, symlink, and traversal policy before exposing resources through the explorer. |
| [ZIT-102](explorer-command-palette-and-status.md#zit-102-implement-open-document-controls) | Implement Open-Document Controls | Show, activate, and close open documents with visible dirty state using tabs or an equivalent stable control. |
| [ZIT-103](explorer-command-palette-and-status.md#zit-103-index-and-filter-command-palette-entries) | Index and Filter Command Palette Entries | Build a searchable palette index from registered command titles and enablement metadata. |
| [ZIT-104](explorer-command-palette-and-status.md#zit-104-execute-commands-from-the-palette) | Execute Commands from the Palette | Dispatch selected palette commands and present progress, cancellation, results, and errors. |
| [ZIT-105](explorer-command-palette-and-status.md#zit-105-implement-the-status-surface) | Implement the Status Surface | Show cursor, selection, encoding, line endings, dirty state, and actionable application status from typed events. |
| [ZIT-106](explorer-command-palette-and-status.md#zit-106-verify-navigation-keyboard-and-accessibility-flows) | Verify Navigation Keyboard and Accessibility Flows | Verify explorer, open-document, palette, status, and editor transitions using keyboard and VoiceOver. |

## Milestone 2: Zig Work Loop

### [Zig Work Loop](zig-work-loop.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-107](zig-work-loop.md#zit-107-build-the-zig-work-loop-sample-project) | Build the Zig Work-Loop Sample Project | Create a deterministic Zig fixture with multiple files, references, diagnostics, formatting cases, build success, and build failure states. |
| [ZIT-108](zig-work-loop.md#zit-108-verify-the-end-to-end-zig-work-loop) | Verify the End-to-End Zig Work Loop | Run the sample project through search, navigation, edit, build, diagnostics, repair, and rebuild with cancellation and failure recovery. |

### [Workspace Search and File Watching](workspace-search-and-file-watching.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-109](workspace-search-and-file-watching.md#zit-109-implement-bounded-workspace-traversal) | Implement Bounded Workspace Traversal | Traverse workspace files with path normalization, symlink policy, size limits, and configurable exclusions. |
| [ZIT-110](workspace-search-and-file-watching.md#zit-110-implement-filename-search) | Implement Filename Search | Match filenames and relative paths with bounded, cancellable result collection. |
| [ZIT-111](workspace-search-and-file-watching.md#zit-111-implement-literal-workspace-text-search) | Implement Literal Workspace Text Search | Search bounded text files for literal UTF-8 queries without requiring an index or regex engine. |
| [ZIT-112](workspace-search-and-file-watching.md#zit-112-stream-and-cancel-search-results) | Stream and Cancel Search Results | Deliver bounded search batches with operation IDs and stop superseded or cancelled searches. |
| [ZIT-113](workspace-search-and-file-watching.md#zit-113-implement-search-result-navigation) | Implement Search Result Navigation | Present filename/text results and navigate to validated resources and ranges. |
| [ZIT-114](workspace-search-and-file-watching.md#zit-114-implement-the-macos-file-watch-adapter) | Implement the macOS File-Watch Adapter | Observe workspace create, modify, rename, and delete activity through the selected macOS API. |
| [ZIT-115](workspace-search-and-file-watching.md#zit-115-reconcile-watch-events-and-rescans) | Reconcile Watch Events and Rescans | Coalesce duplicate/burst events, update explorer state, and trigger bounded rescans when event fidelity is lost. |

### [Task and Process Service](task-and-process-service.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-116](task-and-process-service.md#zit-116-define-task-definitions-and-first-run-trust) | Define Task Definitions and First-Run Trust | Define executable, arguments, working directory, environment allowlist, and a first-run confirmation showing what will execute. |
| [ZIT-117](task-and-process-service.md#zit-117-implement-safe-child-process-spawn) | Implement Safe Child-Process Spawn | Spawn executable argument arrays without implicit shell interpolation and capture process identity. |
| [ZIT-118](task-and-process-service.md#zit-118-stream-standard-output-and-error) | Stream Standard Output and Error | Drain both streams concurrently into bounded output channels while retaining ordering metadata. |
| [ZIT-119](task-and-process-service.md#zit-119-cancel-task-process-trees) | Cancel Task Process Trees | Cancel the child and its relevant process tree using a documented graceful-then-force deadline. |
| [ZIT-120](task-and-process-service.md#zit-120-implement-task-timeouts-and-reaping) | Implement Task Timeouts and Reaping | Enforce optional deadlines, reap every child, and classify exit code, signal, timeout, cancellation, and spawn failure. |
| [ZIT-121](task-and-process-service.md#zit-121-add-the-zig-build-task-and-diagnostic-parsing) | Add the Zig Build Task and Diagnostic Parsing | Provide `zig build` as the first task and parse stable file/range diagnostics while retaining raw output. |
| [ZIT-122](task-and-process-service.md#zit-122-stress-test-task-execution) | Stress-Test Task Execution | Test missing programs, failures, large output, hangs, cancellation, timeouts, descendants, and repeated runs. |

### [LSP Client Lifecycle](lsp-client-lifecycle.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-123](lsp-client-lifecycle.md#zit-123-configure-and-identify-the-zls-executable) | Configure and Identify the ZLS Executable | Resolve a configured or discoverable ZLS executable and capture its version without running workspace code. |
| [ZIT-124](lsp-client-lifecycle.md#zit-124-implement-the-lsp-client-state-machine) | Implement the LSP Client State Machine | Model stopped, starting, initializing, ready, stopping, failed, and restart-wait states explicitly. |
| [ZIT-125](lsp-client-lifecycle.md#zit-125-implement-initialization-and-capability-negotiation) | Implement Initialization and Capability Negotiation | Initialize one local workspace and retain only validated server capabilities. |
| [ZIT-126](lsp-client-lifecycle.md#zit-126-implement-pending-request-correlation) | Implement Pending Request Correlation | Track request IDs, expected response types, deadlines, and completion ownership. |
| [ZIT-127](lsp-client-lifecycle.md#zit-127-synchronize-document-open-change-save-and-close) | Synchronize Document Open, Change, Save, and Close | Translate document lifecycle and validated incremental edits into LSP notifications with monotonic versions. |
| [ZIT-128](lsp-client-lifecycle.md#zit-128-implement-lsp-cancellation-and-deadlines) | Implement LSP Cancellation and Deadlines | Cancel pending requests when explicitly requested, superseded, timed out, or invalidated by document closure. |
| [ZIT-129](lsp-client-lifecycle.md#zit-129-validate-incoming-lsp-messages) | Validate Incoming LSP Messages | Bound and validate message shape, IDs, methods, paths, ranges, and payload sizes before dispatch. |
| [ZIT-130](lsp-client-lifecycle.md#zit-130-implement-graceful-shutdown-and-bounded-restart) | Implement Graceful Shutdown and Bounded Restart | Request protocol shutdown, enforce a process deadline, surface crashes, and restart only within a visible bounded policy. |

### [ZLS Language Features](zls-language-features.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-131](zls-language-features.md#zit-131-register-capability-aware-language-commands) | Register Capability-Aware Language Commands | Register language commands only when negotiated capabilities and current document context permit them. |
| [ZIT-132](zls-language-features.md#zit-132-implement-completion) | Implement Completion | Request, present, filter, and apply completion items through validated edit transactions. |
| [ZIT-133](zls-language-features.md#zit-133-implement-hover) | Implement Hover | Request hover information and display bounded plain or safely rendered content near the relevant range. |
| [ZIT-134](zls-language-features.md#zit-134-implement-go-to-definition) | Implement Go to Definition | Resolve one or more definition locations and open validated workspace resources/ranges. |
| [ZIT-135](zls-language-features.md#zit-135-implement-find-references) | Implement Find References | Request references, present bounded results, and navigate only after resource/range validation. |
| [ZIT-136](zls-language-features.md#zit-136-implement-document-formatting) | Implement Document Formatting | Validate and apply server formatting edits as one reversible transaction. |
| [ZIT-137](zls-language-features.md#zit-137-implement-document-and-workspace-symbols) | Implement Document and Workspace Symbols | Request symbols, display hierarchy or flat results, and navigate to validated locations. |
| [ZIT-138](zls-language-features.md#zit-138-verify-zls-feature-integration) | Verify ZLS Feature Integration | Run all language features against deterministic protocol fixtures and the recorded real ZLS/sample project. |

### [Diagnostics, Problems, and Output](diagnostics-problems-and-output.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-139](diagnostics-problems-and-output.md#zit-139-implement-the-versioned-diagnostic-model) | Implement the Versioned Diagnostic Model | Store owner, resource, version, severity, code, source, message, and validated range in UI-independent diagnostic sets. |
| [ZIT-140](diagnostics-problems-and-output.md#zit-140-implement-diagnostic-owner-lifecycle) | Implement Diagnostic Owner Lifecycle | Atomically replace, clear, and dispose diagnostics by owner/resource. |
| [ZIT-141](diagnostics-problems-and-output.md#zit-141-implement-bounded-output-channels) | Implement Bounded Output Channels | Provide named task, ZLS, extension, and application channels with entry, line, total-size, and retention limits. |
| [ZIT-142](diagnostics-problems-and-output.md#zit-142-implement-the-problems-view) | Implement the Problems View | Present problems grouped or filtered by severity, owner, and workspace with stable keyboard navigation. |
| [ZIT-143](diagnostics-problems-and-output.md#zit-143-validate-problem-navigation) | Validate Problem Navigation | Revalidate resource and range against current workspace/document state when a problem is invoked. |
| [ZIT-144](diagnostics-problems-and-output.md#zit-144-verify-diagnostic-ordering-output-limits-and-redaction) | Verify Diagnostic Ordering, Output Limits, and Redaction | Stress stale diagnostic ordering, owner cleanup, output floods, invalid bytes, limits, and sensitive-field redaction. |

## Milestone 3: Extension Minimum

### [Extension Minimum](extension-minimum.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-145](extension-minimum.md#zit-145-define-the-extension-minimum-exit-suite) | Define the Extension-Minimum Exit Suite | Map every Milestone 3 outcome to protocol, lifecycle, contribution, SDK, crash, timeout, and compatibility evidence. |
| [ZIT-146](extension-minimum.md#zit-146-document-the-version-1-extension-threat-boundary) | Document the Version 1 Extension Threat Boundary | State what process isolation, environment restriction, permission declarations, and trusted local installation do and do not enforce. |

### [Extension Manifest and Protocol Specification](extension-manifest-and-protocol-spec.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-147](extension-manifest-and-protocol-spec.md#zit-147-resolve-protocol-version-representation-in-an-adr) | Resolve Protocol Version Representation in an ADR | Choose one manifest/handshake representation for protocol major and minor versions and record compatibility rules and rejected alternatives. |
| [ZIT-148](extension-manifest-and-protocol-spec.md#zit-148-define-the-extension-manifest-schema) | Define the Extension Manifest Schema | Specify identity, package version, display metadata, protocol version, entrypoint, activation events, contributions, and permissions in JSON Schema. |
| [ZIT-149](extension-manifest-and-protocol-spec.md#zit-149-specify-package-paths-and-platform-executables) | Specify Package Paths and Platform Executables | Define package-root containment, normalization, symlink behavior, executable selection, and macOS arm64 entrypoint rules. |
| [ZIT-150](extension-manifest-and-protocol-spec.md#zit-150-specify-initialization-and-capability-negotiation) | Specify Initialization and Capability Negotiation | Define initialize/initialized payloads, IDE/extension identity, declared/granted capabilities, workspace roots, and limits. |
| [ZIT-151](extension-manifest-and-protocol-spec.md#zit-151-specify-version-1-rpc-methods-and-errors) | Specify Version 1 RPC Methods and Errors | Define command, task, document, diagnostic, notification, output, cancellation, shutdown, and error message contracts. |
| [ZIT-152](extension-manifest-and-protocol-spec.md#zit-152-specify-permissions-and-grants) | Specify Permissions and Grants | Define declared permissions, runtime grants, user-visible wording, and the limits of enforcement. |
| [ZIT-153](extension-manifest-and-protocol-spec.md#zit-153-specify-protocol-resource-limits-and-deadlines) | Specify Protocol Resource Limits and Deadlines | Set message, log, startup, request, cancellation, and shutdown limits with standard error behavior. |
| [ZIT-154](extension-manifest-and-protocol-spec.md#zit-154-publish-protocol-fixtures-and-compatibility-matrix) | Publish Protocol Fixtures and Compatibility Matrix | Publish valid/invalid manifests, handshakes, method payloads, errors, and version combinations as reviewed public fixtures. |

### [Extension Discovery and Validation](extension-discovery-and-validation.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-155](extension-discovery-and-validation.md#zit-155-define-extension-discovery-directories) | Define Extension Discovery Directories | Define user and development extension directories and their deterministic precedence on macOS. |
| [ZIT-156](extension-discovery-and-validation.md#zit-156-parse-manifests-under-explicit-limits) | Parse Manifests Under Explicit Limits | Read and validate manifests with bounded file size, JSON depth, strings, arrays, and diagnostics. |
| [ZIT-157](extension-discovery-and-validation.md#zit-157-validate-extension-package-paths) | Validate Extension Package Paths | Normalize package and entrypoint paths and enforce root/symlink/executable policy. |
| [ZIT-158](extension-discovery-and-validation.md#zit-158-resolve-duplicate-and-unsupported-packages) | Resolve Duplicate and Unsupported Packages | Detect duplicate IDs and unsupported versions using deterministic selection or rejection rules. |
| [ZIT-159](extension-discovery-and-validation.md#zit-159-index-declarative-contributions-and-activation-events) | Index Declarative Contributions and Activation Events | Build an immutable discovery index for approved contributions and activation events without starting processes. |
| [ZIT-160](extension-discovery-and-validation.md#zit-160-adversarially-test-extension-discovery) | Adversarially Test Extension Discovery | Test deep/oversized JSON, path attacks, symlink races where practical, duplicates, mixed validity, and directory changes. |

### [Extension Supervisor](extension-supervisor.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-161](extension-supervisor.md#zit-161-implement-the-extension-lifecycle-state-machine) | Implement the Extension Lifecycle State Machine | Implement discovered, validated, inactive, starting, active, stopping, stopped, and failed states. |
| [ZIT-162](extension-supervisor.md#zit-162-launch-extension-processes-with-a-restricted-environment) | Launch Extension Processes with a Restricted Environment | Launch one process per active extension with argument arrays, documented environment exposure, framed stdout/stdin, and stderr logs. |
| [ZIT-163](extension-supervisor.md#zit-163-implement-extension-initialization-handshake) | Implement Extension Initialization Handshake | Negotiate version, identity, capabilities, grants, roots, and limits before activation completes. |
| [ZIT-164](extension-supervisor.md#zit-164-dispatch-extension-requests-and-notifications) | Dispatch Extension Requests and Notifications | Correlate, validate, and dispatch approved protocol methods between the application and extension. |
| [ZIT-165](extension-supervisor.md#zit-165-enforce-extension-deadlines-and-cancellation) | Enforce Extension Deadlines and Cancellation | Enforce startup, request, cancellation, and shutdown deadlines and clear pending ownership. |
| [ZIT-166](extension-supervisor.md#zit-166-capture-bounded-extension-logs) | Capture Bounded Extension Logs | Route extension stderr into an owned output channel with redaction and retention limits. |
| [ZIT-167](extension-supervisor.md#zit-167-isolate-crashes-and-apply-bounded-restart) | Isolate Crashes and Apply Bounded Restart | Convert unexpected exit and broken transport into extension-owned failure and apply a visible bounded restart policy. |
| [ZIT-168](extension-supervisor.md#zit-168-implement-extension-shutdown-and-reaping) | Implement Extension Shutdown and Reaping | Request graceful shutdown, enforce deadline, force termination if required, reap the child, and release pending calls. |

### [Extension Contribution Points](extension-contribution-points.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-169](extension-contribution-points.md#zit-169-implement-extension-owned-registrations) | Implement Extension-Owned Registrations | Associate every contribution registration and resource with one extension owner and disposable lifetime. |
| [ZIT-170](extension-contribution-points.md#zit-170-implement-command-and-default-keybinding-contributions) | Implement Command and Default-Keybinding Contributions | Index commands/keybindings declaratively and activate the owner lazily when a contributed command executes. |
| [ZIT-171](extension-contribution-points.md#zit-171-implement-language-metadata-contributions) | Implement Language-Metadata Contributions | Register version 1 language IDs, extensions, filenames, and approved metadata without arbitrary code execution. |
| [ZIT-172](extension-contribution-points.md#zit-172-implement-task-provider-contributions) | Implement Task-Provider Contributions | Request bounded task definitions from activated providers and pass approved tasks through existing trust/process services. |
| [ZIT-173](extension-contribution-points.md#zit-173-implement-read-only-document-access) | Implement Read-Only Document Access | Expose bounded, granted document identity, version, and text reads without a version 1 edit capability. |
| [ZIT-174](extension-contribution-points.md#zit-174-implement-diagnostic-contributions) | Implement Diagnostic Contributions | Validate extension-owned diagnostic sets and route them through the diagnostic service. |
| [ZIT-175](extension-contribution-points.md#zit-175-implement-notification-and-output-contributions) | Implement Notification and Output Contributions | Expose bounded notifications and owner-labelled output channels without arbitrary UI injection. |
| [ZIT-176](extension-contribution-points.md#zit-176-verify-contribution-cleanup-and-denials) | Verify Contribution Cleanup and Denials | Test multiple owners, activation, stop, crash, denied grants, malformed payloads, and explicitly unsupported contribution types. |

### [Zig Extension SDK and Examples](zig-extension-sdk-and-examples.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-177](zig-extension-sdk-and-examples.md#zit-177-define-the-public-zig-sdk-package) | Define the Public Zig SDK Package | Create a separately importable SDK package whose API mirrors public protocol concepts without private Zigide imports. |
| [ZIT-178](zig-extension-sdk-and-examples.md#zit-178-implement-sdk-framing-and-json-rpc) | Implement SDK Framing and JSON-RPC | Implement protocol framing, messages, correlation, errors, and bounded transport for extension executables. |
| [ZIT-179](zig-extension-sdk-and-examples.md#zit-179-implement-sdk-initialization-and-cancellation) | Implement SDK Initialization and Cancellation | Expose initialization identity/capabilities/grants plus handler cancellation and graceful shutdown. |
| [ZIT-180](zig-extension-sdk-and-examples.md#zit-180-implement-typed-sdk-contribution-helpers) | Implement Typed SDK Contribution Helpers | Add typed command, task, document, diagnostic, notification, and output helpers for version 1. |
| [ZIT-181](zig-extension-sdk-and-examples.md#zit-181-build-an-sdk-test-transport) | Build an SDK Test Transport | Provide deterministic in-memory or fixture transport for extension handler tests. |
| [ZIT-182](zig-extension-sdk-and-examples.md#zit-182-build-command-and-diagnostics-example-extensions) | Build Command and Diagnostics Example Extensions | Package standalone examples that build independently and run through discovery, supervisor, contributions, and SDK only. |

### [Extension Compatibility and Failure Tests](extension-compatibility-and-failure-tests.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-183](extension-compatibility-and-failure-tests.md#zit-183-implement-supported-version-fixtures) | Implement Supported-Version Fixtures | Run a successful handshake and representative contribution flow for every supported major/minor combination. |
| [ZIT-184](extension-compatibility-and-failure-tests.md#zit-184-build-malformed-extension-peers) | Build Malformed Extension Peers | Generate malformed framing, JSON, handshake, IDs, capabilities, methods, paths, and contribution payloads. |
| [ZIT-185](extension-compatibility-and-failure-tests.md#zit-185-test-extension-timeouts-and-crashes) | Test Extension Timeouts and Crashes | Simulate slow startup, ignored cancellation, request hangs, crash, shutdown refusal, and restart loops. |
| [ZIT-186](extension-compatibility-and-failure-tests.md#zit-186-test-extension-flood-and-size-limits) | Test Extension Flood and Size Limits | Flood frames, logs, output, notifications, diagnostics, and requests to verify all resource limits. |
| [ZIT-187](extension-compatibility-and-failure-tests.md#zit-187-fuzz-manifest-framing-and-protocol-dispatch) | Fuzz Manifest, Framing, and Protocol Dispatch | Add fuzz targets and retain a reproducible regression corpus for discovered parsing and lifecycle defects. |
| [ZIT-188](extension-compatibility-and-failure-tests.md#zit-188-run-extension-compatibility-and-leak-tests-in-ci) | Run Extension Compatibility and Leak Tests in CI | Add bounded CI execution for fixtures, examples, failures, deadlines, and child-process cleanup. |

## Milestone 4: Public Preview

### [Public Preview](public-preview.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-189](public-preview.md#zit-189-define-the-preview-release-candidate-checklist) | Define the Preview Release-Candidate Checklist | Define exact source revision, tool versions, required tests, artifacts, documents, audits, owners, and blocking severity for a preview candidate. |
| [ZIT-190](public-preview.md#zit-190-verify-the-clean-new-user-journey) | Verify the Clean New-User Journey | Verify install, launch, project open, edit/save/recovery, search, build, ZLS, example extension, failure recovery, and issue reporting in an isolated user environment. |

### [macOS Packaging and Integrity](macos-packaging-and-integrity.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-191](macos-packaging-and-integrity.md#zit-191-define-the-application-bundle-layout) | Define the Application Bundle Layout | Define executable, resources, metadata, identity, icons, libraries, and data-location boundaries for the macOS bundle. |
| [ZIT-192](macos-packaging-and-integrity.md#zit-192-produce-final-application-assets-and-metadata) | Produce Final Application Assets and Metadata | Add required icon assets, property metadata, version fields, and accessibility-facing product name for the candidate. |
| [ZIT-193](macos-packaging-and-integrity.md#zit-193-implement-the-clean-release-build) | Implement the Clean Release Build | Add one documented command that produces the app bundle and archive from a clean checkout with pinned inputs. |
| [ZIT-194](macos-packaging-and-integrity.md#zit-194-generate-checksums-and-compare-reproducibility) | Generate Checksums and Compare Reproducibility | Generate cryptographic digests and compare two clean builds under documented reproducibility conditions. |
| [ZIT-195](macos-packaging-and-integrity.md#zit-195-evaluate-signing-and-notarization) | Evaluate Signing and Notarization | Determine whether signing/notarization can be completed and document the exact verified state without storing credentials. |
| [ZIT-196](macos-packaging-and-integrity.md#zit-196-test-install-upgrade-uninstall-and-bundle-integrity) | Test Install, Upgrade, Uninstall, and Bundle Integrity | Test archive verification, install, first launch, upgrade from a prior fixture, removal, user-data retention, and bundle inventory. |

### [User, Extension, Security, and Contribution Documentation](user-extension-security-and-contribution-docs.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-197](user-extension-security-and-contribution-docs.md#zit-197-write-the-user-guide) | Write the User Guide | Document install, open/edit/save/recover, search, build, ZLS, settings, keybindings, logs, extensions, and removal. |
| [ZIT-198](user-extension-security-and-contribution-docs.md#zit-198-write-the-extension-author-guide) | Write the Extension Author Guide | Document manifest, protocol, SDK, capabilities, permissions, examples, compatibility, limits, testing, and debugging. |
| [ZIT-199](user-extension-security-and-contribution-docs.md#zit-199-publish-the-security-policy) | Publish the Security Policy | Document supported versions, private reporting, task trust, extension trust, data locations, logs, and non-sandboxed behavior. |
| [ZIT-200](user-extension-security-and-contribution-docs.md#zit-200-write-the-contribution-guide) | Write the Contribution Guide | Document setup, pinned toolchain, architecture/ADR rules, ticket workflow, tests, trace records, review, and licensing. |
| [ZIT-201](user-extension-security-and-contribution-docs.md#zit-201-write-troubleshooting-and-data-location-guides) | Write Troubleshooting and Data-Location Guides | Document ZLS, tasks, recovery, extensions, diagnostics, logs, configuration reset, and all local data locations. |
| [ZIT-202](user-extension-security-and-contribution-docs.md#zit-202-validate-documentation-end-to-end) | Validate Documentation End to End | Run user, extension-author, security-reporting, and contributor walkthroughs and validate links, commands, schemas, screenshots, and claims. |

### [Performance and Accessibility Review](performance-and-accessibility-review.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-203](performance-and-accessibility-review.md#zit-203-freeze-preview-benchmark-fixtures-and-budgets) | Freeze Preview Benchmark Fixtures and Budgets | Freeze target hardware/OS conditions, fixtures, commands, repetitions, metrics, and blocking budgets for the candidate. |
| [ZIT-204](performance-and-accessibility-review.md#zit-204-measure-startup-and-memory) | Measure Startup and Memory | Measure cold/warm startup, idle memory, workspace-open memory, and shutdown on the target Mac. |
| [ZIT-205](performance-and-accessibility-review.md#zit-205-measure-file-edit-and-scroll-performance) | Measure File, Edit, and Scroll Performance | Measure large-file open, sustained edits, lookup, rendering, scrolling, and memory growth. |
| [ZIT-206](performance-and-accessibility-review.md#zit-206-measure-search-task-and-language-operations) | Measure Search, Task, and Language Operations | Measure workspace search, watcher reconciliation, build output, ZLS startup, and representative language requests while editing. |
| [ZIT-207](performance-and-accessibility-review.md#zit-207-review-keyboard-navigation-and-focus) | Review Keyboard Navigation and Focus | Complete all core workflows without a mouse and inspect visible focus, order, traps, and restoration. |
| [ZIT-208](performance-and-accessibility-review.md#zit-208-review-voiceover-behavior) | Review VoiceOver Behavior | Verify core regions, editor text/selection, problems, command results, status, and actionable errors with VoiceOver. |
| [ZIT-209](performance-and-accessibility-review.md#zit-209-review-ime-scaling-and-publish-results) | Review IME, Scaling, and Publish Results | Reverify IME composition, font fallback, scaling, layout, and consolidate performance/accessibility evidence. |

### [Preview Readiness and Audit](preview-readiness-and-audit.md)

| Ticket | Title | Brief summary |
| --- | --- | --- |
| [ZIT-210](preview-readiness-and-audit.md#zit-210-define-preview-versioning-and-migration-policy) | Define Preview Versioning and Migration Policy | Define preview versions and migration/reset/rollback behavior for settings, workspace state, recovery, extensions, manifests, and protocols. |
| [ZIT-211](preview-readiness-and-audit.md#zit-211-triage-release-blocking-defects-and-limitations) | Triage Release-Blocking Defects and Limitations | Review open work and classify data-loss, security, crash, compatibility, performance, accessibility, and UX defects against release policy. |
| [ZIT-212](preview-readiness-and-audit.md#zit-212-verify-issue-intake) | Verify Issue Intake | Verify issue templates collect reproduction, environment, expected/actual behavior, safe logs, and architecture context where relevant. |
| [ZIT-213](preview-readiness-and-audit.md#zit-213-audit-licenses-and-third-party-notices) | Audit Licenses and Third-Party Notices | Match source, bundled dependencies, assets, adapted code, licenses, and notices to the final bundle inventory. |
| [ZIT-214](preview-readiness-and-audit.md#zit-214-audit-public-ai-records-for-privacy-and-ip) | Audit Public AI Records for Privacy and IP | Review public prompts, outputs, screenshots, paths, and claims for secrets, personal data, proprietary instructions, copyrighted material, and fabricated internals. |
| [ZIT-215](preview-readiness-and-audit.md#zit-215-scan-source-and-artifacts-for-secrets-and-local-leakage) | Scan Source and Artifacts for Secrets and Local Leakage | Scan source, Git history, logs, screenshots, bundle, archive, and generated metadata for secrets, credentials, personal paths, and debug leakage. |
| [ZIT-216](preview-readiness-and-audit.md#zit-216-publish-release-notes-and-final-audit-sign-off) | Publish Release Notes and Final Audit Sign-Off | Publish exact platform/tool assumptions, integrity/signing state, compatibility, security boundaries, known limitations, evidence, and all accepted exceptions. |
