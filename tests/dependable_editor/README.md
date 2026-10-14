# Dependable Editor exit suite

This is the maintained ZIT-042 contract and ZIT-043 journey procedure. It defines
required evidence; it does not certify an editor that has not been implemented.
The [roadmap](../../docs/architecture/05-delivery-roadmap.md#milestone-1-dependable-editor),
[safety contract](../../docs/architecture/04-data-safety-and-operations.md) and
[ADR-0004](../../docs/architecture/decisions/0004-ui-toolkit-selection.md) govern it.
Generated run reports stay in ignored `.zig-cache/`. `docs/milestones/` stays ignored
and untracked. Do not copy historical reports into this directory.

## Exit matrix (ZIT-042)

The machine-readable counterpart is [suite.zig](suite.zig). Every check is required.
An owner being Done enables inspection of its evidence; it does not pass a check.

| Roadmap outcome | Check IDs | Owning tickets | Completion evidence |
| --- | --- | --- | --- |
| Window, editor, explorer, palette, status | shell, navigation | [ZIT-089](../../tickets/macos-application-shell.md#zit-089-verify-shell-lifecycle-and-packaging-smoke-tests), [ZIT-106](../../tickets/explorer-command-palette-and-status.md#zit-106-verify-navigation-keyboard-and-accessibility-flows) | Production-bundle lifecycle and layout integration; observed keyboard/focus/VoiceOver navigation across all five surfaces. |
| Open, edit, selection, undo/redo, save, Save As, external changes | text, documents, history, files | [ZIT-050](../../tickets/production-text-model.md#zit-050-property-test-the-production-text-model), [ZIT-057](../../tickets/document-and-workspace-lifecycle.md#zit-057-reject-stale-workspace-and-document-results), [ZIT-063](../../tickets/selection-undo-and-redo.md#zit-063-bound-and-property-test-edit-history), [ZIT-070](../../tickets/safe-file-io.md#zit-070-fault-test-file-open-and-save) | Production domain/property tests plus real temporary-file integration: exact bytes/selection/version, dirty and identity transitions, conflict cancel/reload/overwrite and faults. |
| Atomic settings | settings, settings-crash | [ZIT-076](../../tickets/configuration-and-keybindings.md#zit-076-expose-configuration-and-keybinding-commands), [ZIT-075](../../tickets/configuration-and-keybindings.md#zit-075-persist-and-watch-configuration-atomically) | Scope/validation/keybinding tests and interrupted persistence; the last valid file survives. |
| Atomic recovery snapshots | recovery | [ZIT-083](../../tickets/crash-recovery.md#zit-083-crash-test-recovery-guarantees) | Child-process crash injection, cadence boundaries, corrupt siblings, divergence decisions and document/session-scoped cleanup. |
| Keyboard, mouse, clipboard, Unicode, accessibility | input, editor-accessibility, navigation, input-latency | [ZIT-099](../../tickets/editor-input-rendering-and-accessibility.md#zit-099-verify-editor-latency-input-and-accessibility), ZIT-106 | Automated input contracts plus observed physical IME, VoiceOver, mouse, focus, scaling and font fallback on the target Mac. |
| Real Zig project editing without tested crash data loss | save-crash, recovery, complete journey | ZIT-070, ZIT-083, [ZIT-043](../../tickets/dependable-editor.md#zit-043-verify-the-end-to-end-editing-journey) | One uninterrupted release-like journey with before/after hashes, injected failures and preserved disk/recovery evidence. |
| Defined and measured large-file budgets | large-file, input-latency | [ZIT-051](../../tickets/production-text-model.md#zit-051-verify-production-text-budgets), ZIT-099 | Approved numeric budgets, exact target/build/fixtures, raw open/lookup/memory and visible UI measurements. |
| Defined and measured sustained-edit budgets | sustained-edit | ZIT-051 | 1,024 scattered edits and paste/delete churn, final oracle comparison, p95 and memory observations under approved limits. |

Evidence spans domain, integration, crash, UI, accessibility and performance layers.
Allocation-failure tests use the leak-detecting allocator. Temporary-filesystem
tests exercise actual adapters, not an in-memory substitute for durability.

## Blocking policy

- **Data loss:** any silent byte/metadata/selection corruption, stale mutation,
  dirty discard, incomplete replacement, recovery loss within the promised cadence,
  or overwrite of newer disk content blocks exit. Preserve fixture state immediately.
- **Accessibility:** inability to complete a core flow by keyboard or VoiceOver,
  lost/trapped focus, inaccessible errors or indefinite input blocking blocks exit.
  Synthetic accessibility queries do not qualify observed screen-reader use.
- **Critical latency:** undefined or unapproved numeric budgets, missing target
  measurements, or a missed approved open/edit/lookup/visible-input/scroll/memory
  limit blocks exit. Record all samples; never hide a miss in an average or silently
  relax a budget. A reviewed contract/ticket change is needed before remeasurement.
- Missing, failed, blocked, stale, unsupported or unrun required evidence blocks
  milestone qualification. No non-data-loss functional failure is implicitly waived.

ZIT-051 owns production storage budgets and ZIT-099 owns visible UI budgets. Before
timing either, record numeric limits, units, percentile calculation (nearest-rank
p95), sample counts, warmups, hardware, OS, power/load conditions and memory method.
Use at least 31 measured samples after warmup and retain maximum and sample count.
Reuse the small (4 KiB), medium (256 KiB), large/long-line (4 MiB), and UTF-8 workload
definitions in [the text benchmark](../../tools/text_benchmark.zig). Measure production
storage and visible UI separately. Existing spike measurements cannot satisfy them.
Until approved limits and target observations exist, performance acceptance is unrun.

## Checks available now

Use pinned Zig 0.16.0; keep builds to two jobs on a shared Mac.

```sh
zig build dependable-editor-test -Doptimize=ReleaseSafe -j2 --summary all
zig build dependable-editor-preflight -Doptimize=ReleaseSafe -j2 --summary all
```

The first command tests the exit contract, exact ticket/ADR parsing, dependency
drift, blocker transitions, live owner references and compilation of the maintained
two-file Zig fixture. It is included in `zig build test` and `zig build check`.
Passing these tests establishes the contract/tooling only.

The second command inspects the nine declared ZIT-043 dependencies and ADR-0004,
then writes `.zig-cache/dependable-editor-preflight.json`. The executable exits 2
for `blocked` or `unrun` (the build wrapper reports failure). Parse/read/provenance
errors fail before producing a new report; do not consume an old report as a new run.
Readiness can only change `blocked` to `unrun`; this tool never runs or passes the
journey. Its report always says `journey_executed=false` and
`milestone_qualified=false`, and includes owner status, target, Zig/build mode,
source revision/dirty flag, executable SHA-256 and fixture byte counts/SHA-256.
An accepted superseding UI ADR requires an explicit gate update and review.

## Release-like journey (ZIT-043)

Run only after the declared dependency tickets are Done, an accepted UI decision
exists, and production evidence adapters are available. ADR-0004 now accepts DVUI;
the dependency and qualification requirements remain unmet. This procedure is
currently blocked; neither the headless executable nor a UI spike
can stand in for the production editor. Add automation against the real production
command/input paths as their owning tickets land; do not mark this ticket Done
from preflight results alone.

1. **Prepare and identify.** Record UTC time, source revision and clean/dirty state,
   pinned Zig version, ReleaseSafe production build command, binary/bundle hash,
   toolkit version, Mac hardware, OS/build, filesystem, display scale and load.
   Copy [main.zig](fixtures/main.zig) and [message.zig](fixtures/message.zig) into a
   uniquely named task-owned temporary workspace. Record hashes before edits;
   use isolated settings/recovery directories and a private pasteboard. Generate
   separate LF, CRLF, mixed-ending, no-final-newline and invalid-UTF-8 variants with
   exact bytes/hash recorded. Include read-only, missing and oversized resources.
2. **Open and navigate.** Launch one production bundle, open the fixture folder,
   use the explorer to open both files and revisit one through an equivalent path.
   Check one document identity per resource and coherent active/status/focus state.
   Reach explorer, editor, palette, documents and status by keyboard without a mouse.
3. **Edit and reverse.** Select `greeting`, edit both files, paste the Unicode
   greeting and replace a selection. Compare bytes and selection with an oracle
   after undo and redo in each document. Undo then branch; verify redo policy.
   Cancel a dirty close/workspace switch and verify all state remains intact.
4. **Save and diverge.** Save one file and Save As the other. Reopen and compare
   bytes, line endings, final newline, identity and permissions. Make an external
   edit while a document is dirty. Cancel the conflict first (disk and buffer
   unchanged), then exercise inspect/reload with explicit discard approval and
   explicit overwrite on independent fixture copies. Invalid decoding must not
   silently replace bytes or create an editable lossy document.
5. **Settings and bindings.** Inspect effective default/user/workspace values;
   change one setting and binding, introduce an invalid sibling and reload.
   Verify diagnostics, source scope, valid siblings, atomic persistence and stale
   reload rejection through the same commands used by keyboard and palette.
6. **Crash and recover.** On independent fixture copies, terminate only the test
   child at instrumented save temp-write, sync, pre/post rename and recovery
   manifest/snapshot boundaries. Also test write/permission/rename failure.
   Preserve old/new disk bytes, dirty content, snapshots, errors and process exit
   status. Relaunch; restore edits within the promised cadence. Change disk again
   before restore; cancel must preserve both versions, and newer disk content
   must never be overwritten automatically. Isolate corrupt/orphan sibling data;
   clean only matching data after successful save or explicit discard.
7. **Observe input and accessibility.** In a coordinated, uninterrupted session,
   observe mouse selection, clipboard, Arabic/RTL rendering, font fallback,
   physical composing-IME update/candidate/commit/cancel, resize/display scaling,
   and VoiceOver text/selection/commands/errors/focus restoration. Record actual
   observed actions and outcomes. Missing devices, interaction approval or a live
   composing input source means unrun; paste and synthetic marked text do not pass.
8. **Measure and close.** Run the approved production large-file/sustained-edit
   and visible-input budgets while background results arrive; retain raw samples
   and oracle results. Reopen the edited project after clean shutdown, verify
   saved bytes, settings and resolved recovery cleanup, and recheck focus/navigation.

For each step retain case ID, owner, exact revision/binary/fixture hashes, action,
expected/actual bytes/state, `passed|failed|blocked|unrun`, safe error and evidence
path. Include failure stage/child PID ownership and filesystem-specific durability
limits for crash cases. Record observed VoiceOver/IME evidence separately from
automated probes. A milestone decision needs every matrix check and journey step
passed at the same candidate revision, with approved budgets and no unresolved
blocking failure. Record blockers under their owning tickets and preserve artifacts;
do not silently expand this epic into all prerequisite implementations.
