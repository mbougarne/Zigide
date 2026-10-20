# Production text contract

[ZIT-044–051](../../tickets/production-text-model.md) expose `Document`, `Snapshot`,
`Position`, `Range`, `Edit` and `Metadata` from [module.zig](module.zig).
The spike `Reference` and `PieceTable` remain independent comparison candidates.
Production consumers use `Document`; they do not depend on piece descriptors.

## Coordinates and edits

Positions and offsets are zero-based **UTF-8 byte** coordinates. Range endpoints
must be scalar boundaries; columns include line terminator bytes, including the
LF inside CRLF. EOF is addressable, and a final ending creates an empty last line.
The [reference semantics](README.md#reference-behavior) apply unchanged. Grapheme,
UTF-16, LSP and DVUI conversion belongs outside this domain module.
`Range.normalized` orders offsets; document reads validate bounds and boundaries.
`comparePositions` orders positions lexicographically without accessing text.

`apply` accepts edits in any order, all against the version at call entry. It
validates every range and inserted UTF-8 string, sorts an owned edit descriptor
copy, and rejects overlap or coincident starts (including ambiguous insertions).
Adjacent ranges and an insertion at a preceding range's end are allowed. Inserted
slices are borrowed for the call and must not alias mutable document buffers;
owned snapshots are valid inputs. Empty batches and batches containing only empty
insertions preserve the version. Any other successful batch advances the `u64`
version once, even when replacement bytes equal the old bytes. Version exhaustion
returns `Overflow` before mutation.

Storage descriptors, insertion bytes, compaction and the next line index are
prepared before commit. Validation, overflow or allocation failure preserves
content, version, metadata and lookups. Reserved capacity may grow on failure.
A single application thread owns each mutable document; reentrant mutation and
copying owning structs are unsupported. Implementation fields are not read APIs.

`prepare` exposes the same validated mutation before publication. Its owned
`Prepared` value supports candidate-position validation, then exactly one `commit`
or `deinit`. The document stays at a stable address and is not accessed while a
prepared value borrows it. This lets [selection/history](HISTORY.md) allocate
inverse edits and validate post-edit selections before committing text, metadata,
selection and history together. Ordinary `apply` prepares and commits directly.

## Ownership and indexing

Construction copies valid UTF-8 into an owned original buffer. Coalesced pieces
reference that buffer and an append-only add buffer. Cumulative piece ends and
line starts support binary-search lookup, O(log pieces + log lines). Read copies
only the selected range; callers supply exactly sized output. Edit preparation
copies descriptors and line starts, O(pieces + lines + affected bytes), with a
sort costing O(batch size × log batch size). No tree dependency is needed for the
measured workloads.

Line-ending changes rescan only the span between the first and last edit plus
unchanged edge bytes, expanding either edge inside CRLF. Unchanged prefix starts
are retained; suffix starts shift once. Edits that cannot affect endings shift
starts directly. Widely separated edits can still scan their intervening span.

Dead add-buffer history is compacted when logical added bytes exceed
`2 × max(new document bytes, 64 KiB)`. Compaction copies the live candidate into a
fresh original buffer inside the same transaction; failure rolls back the batch.
The threshold bounds logical history, not allocator capacity or RSS. Original
bytes remain owned until compaction or destruction. Allocation capacity can exceed
the threshold according to the allocator/list growth policy. This is a storage
policy; undo history and its separate budget belong to ZIT-058–063.

The document borrows its allocator through `deinit`. `snapshot(allocator)` owns a
complete immutable copy, its version and metadata. Its supplied allocator must
outlive the snapshot; the caller transfers sole ownership to a worker and calls
`Snapshot.deinit` exactly once. Concurrent reads are safe while it remains alive.
Snapshot release cannot affect a document; document edits/destruction cannot affect
a snapshot. Copying costs O(bytes + pieces), with no shared refcounts or locks.

## Encoding and metadata

Invalid UTF-8 returns `InvalidUtf8` before construction or mutation, including
surrogates, overlong and truncated input. The caller retains the rejected bytes;
the file adapter owns unsupported-encoding handling. Accepted documents report
`valid_utf8`. BOM bytes are preserved as ordinary content and separately reported.
No bytes are stripped, replaced or normalized. Counts distinguish LF, CRLF and
lone CR, including split-piece CRLF; metadata exposes none, one form, or mixed,
and the actual final-newline state. Metadata updates in the same commit as text.

## Reproduction

Use the pinned Zig 0.16.0 toolchain:

```sh
zig build production-text-test -Doptimize=ReleaseSafe -j2 --summary all
zig build production-text-benchmark -Doptimize=ReleaseFast -j2 -- .zig-cache/production-text.csv
zig build production-text-summary -Doptimize=ReleaseFast -j2 -- .zig-cache/production-text.csv .zig-cache/production-text-summary.csv --check-budgets
zig build check -Doptimize=ReleaseSafe -j2 --summary all
```

With a restricted home directory, append `--global-cache-dir <task-owned-cache>`
to Zig commands. `production-text-test` covers ownership, invalid boundaries,
batches, snapshots, metadata, allocation failure (including compaction), 32 fixed
seeds × 512 batches, all scalar offsets, invalid positions and retained snapshots.
The retained seed `0x5a4954044051`, prefix 26, exposed a lost prefix line start;
a focused regression remains alongside the seeded replay. Additional cases cover
65,536-byte fragmented long lines and randomized updates among mixed endings.
`text-test` and `check` include production correctness. Deterministic property tests
do not establish that a coverage-guided fuzz campaign ran.

Benchmarks reuse all five spike fixtures, 31 observations after one warmup per
operation, 1,024 scattered/alternating-end replacements (seed `0x027033`), and 64
4-KiB paste/delete cycles. Production adds a two-edit batch and four retained
snapshots. It checks final/churn/snapshot bytes against the independent reference
and verifies allocator accounting returns to zero. Raw CSV, logs and summaries
stay in ignored `.zig-cache/`; no milestone logs or artifacts are restored.
CI retains measurements, without qualifying hardware-specific budgets.

See [budget evidence](production-budgets.md) and [deferred tooling limits](../../internals/production-text-follow-ups.md).
