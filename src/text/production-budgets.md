# Production text budget evidence

ZIT-051 uses the existing spike fixture generator and operation distribution in
[the benchmark](../../tools/text_benchmark.zig). The historical ignored milestone
report is absent, so its numeric preliminary thresholds cannot be verified.
The following are **initial production checkpoint proposals**, not a claim of
previous maintainer approval. ZIT-051 remains In Progress pending approval of these
thresholds. No final measured group misses them; the earlier long-line miss was
fixed before the two final runs.

## Reproducible conditions

- Target: Apple M3 Pro, Mac15,6, 18 GiB RAM; macOS 27.0.1 (26A434), aarch64.
- Toolchain: Zig 0.16.0, `-Doptimize=ReleaseFast -j2`; synthetic in-process data,
  no file I/O in timed regions, no UI, no live provider.
- Two complete final runs on 2026-10-15 UTC, with ordinary host activity present;
  this is not an isolated/quiescent machine or a claim of worst-case latency.
- Five fixtures: 4 KiB, 256 KiB, 4 MiB, 4 MiB single line, and 262,140-byte UTF-8.
  Each is a whole number of the existing repeated patterns. All generated data
  is original synthetic project content.
- One warmup then 31 samples per ordinary operation, 1,024 sustained replacements,
  64 paste/delete cycles, 31 lookups each after fragmentation, four held snapshots.
  Each run retains 7,330 rows and 85 fixture/operation groups.
- Median and p95 use nearest-rank; maxima remain in CSV. Nanosecond clock values
  are not an assertion of equivalent timer precision; very short samples can be 0.
- Allocation numbers count requested bytes, including temporary peaks, descriptors,
  line starts and snapshots; they exclude allocator bookkeeping, fixture/oracle
  memory, process RSS and OS caching. Every model returns its accounting to zero.

## Proposed gates and results

The Zig [summarizer](../../tools/production_text_summary.zig) enforces these gates
when invoked with `--check-budgets`. All five fixtures and both final runs pass.
CI collects comparable CSV but does not apply target-Mac thresholds on unknown
runner hardware.

| Metric | Proposed checkpoint gate | Worst final result across both runs |
| --- | --- | --- |
| Open p95 | 50 ms | 27.884 ms (4 MiB many-line file) |
| Insert/delete/replace, batch, sustained and churn p95 | 16 ms | 12.945 ms (two far-separated edits on 4 MiB) |
| Snapshot p95 | 10 ms | 0.939 ms (4 MiB) |
| Both lookup directions, before/after fragmentation, p95 | 10 µs | 0.250 µs |
| Peak requested bytes, including four snapshots | `8 × fixture bytes + 512 KiB` | 23,805,768 B for 4 MiB; gate 34,078,720 B |

The two-edit workload spans the document prefix and midpoint. Index updates can
scan that intervening span; the result is included rather than treating every
batch as a cheap single edit. A max individual large-file insertion sample in
run 2 was 17.771 ms while its p95 was 0.901 ms. These are p95 gates, not maximum
latency guarantees. The snapshots are deliberately full copies; retaining more
snapshots adds roughly one live document size each and requires a caller budget.

| 4 MiB fixture metric (p95) | Final run 1 | Final run 2 |
| --- | --- | --- |
| Many-line open | 7.807 ms | 27.884 ms |
| Many-line sustained replacement | 0.199 ms | 0.700 ms |
| Many-line two-edit batch | 6.993 ms | 12.945 ms |
| Long-line newline insertion | 1.459 µs | 10.250 µs |
| Long-line sustained replacement | 10.250 µs | 11.708 µs |

An earlier run measured 17.329 ms p95 for a newline insertion into the long line,
missing the proposed 16 ms gate. Reducing line/metadata rescans from whole lines
to the edited byte span plus complete CRLF context resolved the defect. The
threshold was not raised to accommodate it. Both corrected runs remeasure every
fixture and operation; tests retain index/CRLF and seeded regressions.

## Retained local evidence

Raw and summary CSV files remain under ignored `.zig-cache/` in the task worktree,
with no tracked milestone artifacts:

- `production-text-final1.csv` / `production-text-final-summary1.csv`
- `production-text-final2.csv` / `production-text-final-summary2.csv`

SHA-256 of the raw files:

```text
4b21727736d41be20c8b3fd9ddb3ab42a7d3ff0cdc107efe4f3ed17c27495673  production-text-final1.csv
282595a294c4c6199ef30e3b2026957ae427f21a6e6423583cecf701e70ddf1f  production-text-final2.csv
```

Use the commands in [Production text contract](PRODUCTION.md#reproduction) for a
fresh run and the exact comparisons. These are domain measurements on the target
hardware. Full editor rendering, IME, VoiceOver, operator and milestone acceptance
remain separate; this does not qualify the end-to-end journey from PR #10.

Numeric threshold acceptance may remain explicitly pending in a draft PR. The original ZIT-051 criterion requires accepted reasons and follow-ups for missed budgets before milestone exit; it does not add a separate numeric-approval gate before draft publication.
