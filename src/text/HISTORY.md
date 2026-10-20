# Selection, transactions and history

[ZIT-058–063](../../tickets/selection-undo-and-redo.md) add `Selection`,
`History`, `EditTransaction`, `EditCommand`, `HistoryLimits` and `HistoryOutcome`
to the text module. These are application-thread domain values. They do not import
DVUI, OS input events, timers, file services or protocol types.

## Selection

Anchor and active endpoints are zero-based UTF-8 byte offsets stamped with the
current document version. Endpoints must be scalar boundaries, including EOF;
positions use the existing line-index conversion. The normalized half-open range
preserves the original anchor/active direction (empty, forward or reverse).
A stale version or split scalar is rejected before mutation.

Each transaction either supplies validated post-edit endpoints or transforms both
endpoints through its normalized original-coordinate batch. Both have right
affinity: an endpoint at an insertion, or within/on a replacement, moves to the
inserted text's end. Later endpoints shift by the length delta. Adjacent edits are
one replacement span. Reverse selection direction is retained unless endpoints
collapse together. Selecting explicitly creates a grouping boundary, even when
selecting the same position. Selection-only/no-op requests do not discard redo.

## Transactions and atomicity

One history belongs to one mutable `Document`; callers must not mutate the model
outside that history while it is attached. The history's current selection/version
is checked at each operation. `EditTransaction` includes the expected version,
a batch, optional after-selection and command metadata (`kind`, owned command ID).
Typing, paste, formatting, external edits and other commands share this form.

History copies inserted and removed bytes, sorts and validates the whole batch,
and normalizes adjacent edits. Normalization avoids ambiguous coincident inverse
insertions when adjacent ranges are deleted. The text model prepares its existing
piece/index/metadata update. After-selection validation and all history allocations
complete before the prepared edit commits. Validation, allocation, version overflow
or history-budget failure preserves content, selection, metadata, undo/redo cursor
and redo branch. Reserved text-buffer capacity may grow on allocation failure,
as in the existing production contract.

`undo` applies one complete inverse batch and restores the transaction's before
endpoints; `redo` applies its forward batch and restores after endpoints. Every
successful replay advances the current text version once; historical version
numbers are never reused. Exact bytes restore BOM, line endings and final newline
through the ordinary metadata update. Empty history returns the observable `empty`
outcome without changing text/version. Invalid or failed replay keeps the cursor.
A successful new text edit after undo releases the entire redo suffix. Invalid
and no-op edits retain it. `clear` releases history without changing document data.

## Deterministic coalescence

Compatible single-range typing/backspace/forward-delete actions can share a
transaction. There is no clock or timeout. Adjacent insertions require matching
command IDs, empty continuous selections and correct caret advancement. Typing
with CR/LF starts a separate group. Backspace groups extend left; forward-delete
groups extend right. Selected replacements and multi-range batches remain separate.
Paste, formatting, ordinary commands and external edits never coalesce.

`boundary` breaks a group without editing data. Cursor/selection operations,
undo/redo, limit changes and focus transitions are boundaries. Workspace activation
breaks groups in both the outgoing and incoming document. Save acknowledgement
breaks grouping so subsequent typing can undo back to the saved checkpoint;
external-change notification breaks grouping without replacing buffer/history.
A focus adapter can call `Session.historyBoundary` when leaving the editor while
keeping the same active document. Command metadata must describe the real action.

## Ownership and limits

Defaults retain at most 1,024 complete transactions and 8 MiB of requested history
allocations. Linked nodes and exactly sized edit/byte/command buffers avoid hidden
list capacity. Accounting includes each node, both edit arrays, inserted/removed
bytes and copied command IDs; the fixed `History` value, allocator overhead,
document storage and saved baselines are separate. Group merging is capped at
64 KiB by default to bound the copying per keystroke. A larger command transaction
can still fit the overall budget; it simply does not merge into another group.

After a successful commit, evict oldest applied transactions until both retained
limits hold. Lowering limits while undone first removes oldest applied history,
then newest redo entries, preserving the remaining redo prefix. Eviction never
edits document data. A single transaction larger than the configured byte budget,
or any text transaction with a zero entry limit, returns `HistoryLimitExceeded`
before mutation. Callers may explicitly change limits; edits are never silently
made non-undoable. Undo/redo and close free discarded allocations deterministically.

The retained budget does not cap transient edit preparation: old history, the
candidate transaction, a possible merged group and prepared piece/index data can
coexist until atomic commit. Failure releases all candidate allocations. The
existing storage compaction policy remains independent of history limits.

## Workspace integration and checks

Each open workspace document owns its history; views expose selection and undo/
redo availability. `Session.transaction`, `select`, `undo` and `redo` share existing
mutation admission and dirty-state notifications. Byte equality with the saved
snapshot still controls clean state, so undo to saved content becomes clean even
with a newer version. Replay advances the lifecycle revision and invalidates older
background results. Close/reopen gives a fresh history; cancelled close preserves
it. `Session.edit` and accepted background edits now use ordinary transactions.

`zig build history-test` contains focused selection/transaction/replay/grouping/
allocation/limit cases and a contiguous-string oracle with 16 fixed seeds × 256
mixed edit/undo/redo/branch steps, followed by complete history round trips.
The seed and step are printed on failure. Workspace tests cover focus/save/dirty
and stale-result behavior. The normal `text-test` and `check` graph includes history
coverage. These tests do not qualify physical keyboard shortcuts or DVUI behavior.
