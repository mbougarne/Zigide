# Text-model spike contract

The versioned production API is documented in [Production text contract](PRODUCTION.md).

[ZIT-027–033](../../tickets/text-model-spike.md) compare an independent contiguous
[reference model](reference.zig) with an owned [piece table](piece_table.zig).
These are single-edit storage candidates, not the versioned production document
API assigned to ZIT-044–051.

## Reference behavior

- Input and insertions must be valid UTF-8. Invalid sequences, overlong encodings,
  surrogates, and incomplete scalars return `InvalidUtf8`; bytes are never replaced.
- Offsets and zero-based columns count **bytes**, not graphemes, Unicode scalars,
  UTF-16 units, or screen cells. Offsets must lie on scalar boundaries. LSP/UI
  conversion belongs outside this module.
- An edit replaces `[start, end)` with borrowed insertion bytes. Equal endpoints
  insert; an empty insertion deletes; replacing `[0, length)` replaces all text.
  Empty insertions at equal endpoints are valid. Reversed/out-of-range endpoints
  return `InvalidRange`; splitting a scalar returns `InvalidBoundary`.
- LF, CRLF, and lone CR terminate lines. Endings and final-newline state remain
  byte-for-byte unchanged unless explicitly edited. CRLF is one ending even when
  its bytes live in separate pieces. A position at LF inside CRLF belongs to the
  preceding line. Terminator bytes are addressable byte columns; the next line
  owns its starting offset. Thus every scalar boundary has one canonical position.
- Empty text has position `(0, 0)`. EOF is addressable; a final ending creates an
  empty last line. A missing line, a column reaching the next line's start, a
  column past EOF, and arithmetic-sized invalid columns return `InvalidPosition`.
  A column splitting a scalar returns `InvalidBoundary`.
- Validation and all fallible allocation finish before publishing new content,
  descriptors, or line starts. Errors leave logical text and lookups unchanged;
  reserved allocation capacity may increase after a failed edit.

## Ownership and structure

Both models borrow one allocator for their complete lifetime and copy initial
input. `deinit` releases all model storage. Insertion slices are borrowed for the
call; callers supply independent input or snapshots, not aliases into the mutable
add buffer. Struct fields are implementation details, not read APIs. `snapshot`
returns an independent owned copy using the caller's allocator, which the caller
must free; it survives subsequent edits and destruction of the source model.

The reference allocates a new string on each edit and scans endings for both
lookup directions. It shares UTF-8 validation and types, but no piece operations
or index implementation with the candidate. The table owns original/add buffers,
coalesces contiguous same-source descriptors, and rebuilds line starts by streaming
pieces, including CRLF across piece boundaries. Position lookup binary-searches
line starts; scalar-boundary validation still traverses a flat descriptor array.
Edits are O(text bytes + pieces + lines); snapshots are O(text bytes + pieces).
Deleted add-buffer bytes remain owned until deinit. No compaction, transactions,
undo, versions, file decoding, UI, or protocol conversions are claimed.

## Reproduction and evidence types

Use pinned Zig 0.16.0. `zig build text-test` runs boundary/invalid-input tests,
allocation-failure injection, 32 seeds × 512 edits with all-position comparisons,
and four fuzz corpus inputs. Failures print the seed and shortest failing prefix
(the first failing operation stops the sequence); this is prefix reduction, not
an arbitrary sequence minimizer. The leak-detecting test allocator owns every
case. `zig build check` includes this suite and ordinary repository checks.

`zig build text-test --fuzz=10000` requests a separate coverage-guided campaign.
Corpus replay during ordinary tests does **not** establish that a campaign ran.
The pinned Zig 0.16.0 runner fails to compile in fuzz mode at
`compiler/test_runner.zig:566` because `builtin.StackTrace` and `debug.StackTrace`
are incompatible. The coverage-guided campaign has not run.

`zig build text-benchmark -Doptimize=ReleaseFast -- .zig-cache/text-benchmark.csv`
runs the generated workloads and writes raw timings and requested-byte accounting.
`python3 tools/summarize_text_benchmark.py .zig-cache/text-benchmark.csv > .zig-cache/text-benchmark-summary.csv` emits
median, nearest-rank p95, maximum, sample counts, and memory checkpoints using
only Python's standard library. Benchmarks are separate acceptance evidence.

Generated measurements, summaries and logs stay in ignored `.zig-cache/`; they
are not IDE runtime inputs. CI uploads its raw CSV as a downloadable artifact.
Maintained regression fixtures stay tracked.
