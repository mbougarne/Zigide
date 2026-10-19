# Document and workspace lifecycle

`Session` owns one folder identity, its open `text.Document` instances, saved
snapshots, active-document state, scoped subscriptions and pending operation
stamps. `application.Workspace` resolves paths through `ports.Resources` before
calling the domain. `adapters.LocalResources` implements existing local resources.
No domain method opens dialogs, reads/writes files, executes workspace code or
imports DVUI. File decoding/safe save and the production UI remain separate tickets.

## Resource identity (ZIT-052)

An identity is an owned physical absolute path with no empty, `.` or `..`
components or trailing separator (except `/`). Equality compares canonical bytes.
The macOS adapter obtains the filesystem path through a handle, following symlinks
before domain boundary checks; it never collapses `..` before resolving a link.
Relative input requires an explicit absolute base. Document paths use the workspace
root as that base. Empty paths, embedded NUL, dangling links and loops fail.
Only existing readable folders and regular files are accepted. Missing roots,
access denial and non-directories remain distinct contextual application errors.

Case and Unicode equivalence follow the mounted filesystem's canonical spelling;
the domain never lowercases or invents Unicode normalization. Alternate case on a
case-insensitive volume resolves to the same identity. A case-sensitive volume
keeps distinct names distinct. Hard links remain distinct paths; identity follows
the pathname through atomic file replacement rather than pinning an inode.
A workspace symlink may resolve to its physical root. An interior symlink outside
that root is rejected for document admission, as is a sibling sharing a string
prefix. `/` contains all absolute identities; the root itself is not a document.
New-file/Save As identities and rename reconciliation belong to their file tickets.

Canonical paths describe admission at resolution time. They are not filesystem
capabilities or a hostile-code sandbox. Concurrent rename/link changes require
fresh validation by file read/write adapters. The lifecycle API itself never
performs destructive filesystem operations or treats an access check as permission
to overwrite data.

## Ownership and editing (ZIT-053–055)

Keep each owner at a stable address on one application thread. `Resource` and
`Snapshot` own their allocations and are deinitialized once; resource arguments
are borrowed and copied on admission. Each document owns a production text model
and its last acknowledged immutable save snapshot. Registry pointers remain
stable across growth. Views borrow read-only state until mutation/close; workers
receive independent snapshots with explicitly owned allocator lifetimes.

Reopening an admitted resource returns and activates its existing document,
ignoring replacement input bytes. Document IDs are monotonically allocated and
never reused within the session. Invalid bytes or failed allocations leave the
registry and active state unchanged. Close releases every document, baseline and
pending stamp; workspace close also releases all scoped event contexts.
`deinit` requires a completed close and never implies permission to discard edits.

Dirty means bytes differ from the acknowledged snapshot, or an unresolved external
change was reported. The comparison preserves UTF-8, BOM, line endings and final
newline exactly. A successful inverse edit can return to clean despite a higher
text version. This supports the later undo service without introducing its history
here. A save acknowledgement must match a current save operation and exact
snapshot bytes/version. Late acknowledgements cannot clear newer edits or external
changes. An external notification marks conflict/dirty and leaves buffer bytes
untouched; actual reload/conflict resolution remains the file service's decision.

Typed active/dirty events fire once per actual state transition, including the
active fallback on close. Subscribers may read state; reentrant mutation returns
`Busy`. Workspace subscriptions expire at close/switch; stale handles cannot
remove a later workspace's subscription while the session remains alive.

## Close and shutdown admission (ZIT-056)

Closing one document, the workspace, switching roots and preparing shutdown share
`ClosePolicy`: save, discard or cancel. Every dirty document requires an explicit
decision. All decisions are gathered before saving or removing any document.
Cancel or a prompt failure preserves documents, active state, dirty state, workspace
generation and pending operations. Clean teardown and explicit discard allocate
nothing. A switch resolves and owns the replacement root before prompting; failure
keeps the existing workspace.

All save snapshots are allocated before the first save callback. The callback must
safely persist the exact borrowed snapshot and handle external conflicts; success
is an acknowledgement, not an instruction to use an unsafe write. Without a saver,
Save returns `SaveUnavailable`. A failed save aborts close and retains every open
document. Earlier saves that succeeded remain honestly acknowledged; disk writes
cannot be rolled back by a later failure. Discard only removes in-memory ownership.
Callbacks cannot reenter mutation. No worker joining occurs inside domain teardown;
worker owners cancel/join workers before destroying their tokens or the session.

Call `application.Workspace.prepareShutdown` before `Context.shutdown` closes
command admission. A cancelled decision leaves the context available for editing.
Only after admission succeeds should the composition owner run existing service
shutdown/release phases and finally deinitialize the session. The current headless
executable owns no workspace; production UI composition is outside this batch.

## Background results (ZIT-057)

`beginWork` records owner identity, a monotonic operation ID, workspace generation,
document ID, text version, state revision, work kind and borrowed cancellation token.
The revision also changes on external notifications. A newer operation supersedes
only the same target/kind; independent kinds do not invalidate one another.
Closing removes target operations; switching clears all of them. Generations and
IDs never wrap. The cancellation source must outlive completion or explicit worker
teardown; a stamp never owns or frees the source.

Workers return `Result(T)` with a typed success payload or error. The application
thread accepts each tracked completion at most once, using the stored cancellation
state. Wrong owners/stamps, old versions, closed/reopened documents, old workspace
generations, superseded operations and cancelled tokens are rejected. Stale errors
are discarded too. `applyResult` gates an edit payload and its mutation together;
`complete` gates read-only results before application-thread consumers use them.
Payload/snapshot ownership stays with the caller even when rejected. No result
callback may mutate a document from a worker thread.

## Checks

`zig build workspace-test -Doptimize=ReleaseSafe -j2` covers resources, registry,
dirty/active transitions, transactional decisions, save failures, allocation
failures and stale results. `zig build integration-test` exercises real temporary
folders and symlinks through the application/resolver seam, alongside deterministic
missing/unreadable/non-directory failures. Both are included in `zig build check`.
These headless contracts do not qualify physical DVUI prompts, IME or accessibility.
