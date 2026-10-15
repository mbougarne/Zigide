# Production text model: manual test checklist (ZIT-044–051)

**Operator status: UNRUN.** The user owns the manual acceptance below. The agent
is separately authorized to run one exclusive serial headless publication hook.
Run these operator steps after Mac memory pressure recovers, one command at a time.
This batch implements the headless text domain. It does not integrate an editor
window: visual editing in the current application cannot qualify these contracts.
No Chrome, emulator, VoiceOver or input-source changes are needed for this batch.

## Prerequisites and isolated setup

- The task worktree currently resides at `/tmp/zigide-zit044-production`, on branch
  `ZIT-044/production-text-model`. Use the published PR head and record any local
  changes before testing. Preserve this worktree and existing evidence until handoff.
- Install/use the repository's pinned Zig **0.16.0**. No new Python, Docker service,
  live provider, account, credential or production data is needed.
- Close memory-heavy applications yourself and allow the Mac to recover. Commands
  below use `-j1` to limit concurrent compilation. Do not run them in parallel.

```sh
cd /tmp/zigide-zit044-production
zig version
git branch --show-current
git status --short
ZIT_TEXT_TEST_DIR=$(mktemp -d /tmp/zigide-production-text-tests.XXXXXX)
printf 'Keep this evidence directory: %s\n' "$ZIT_TEXT_TEST_DIR"
```

Expected: Zig prints `0.16.0`; the branch matches above. Record the current commit
and preserve the dirty worktree. All tests use synthetic in-memory text and the
suite's temporary fixtures. Never point fixtures or outputs at personal projects,
production documents, recovery data, settings or user libraries.

## Focused ticket checks

Status for every row below: **UNRUN BY OPERATOR**. The tests assert the stated
behavior; success means every selected test passes with no leak report.

Run one ticket at a time using this command, changing the source/filter according
to the table:

```sh
zig test src/text/storage.zig --test-filter ZIT-044 \
  --cache-dir "$ZIT_TEXT_TEST_DIR/cache" \
  --global-cache-dir "$ZIT_TEXT_TEST_DIR/global-cache"
```

| Ticket | Source and filter | Cases and expected results |
| --- | --- | --- |
| ZIT-044 | `src/text/storage.zig`, `ZIT-044` | Owned insert/delete/replace/read; `aé\r\nb` becomes `x😀\r\nb`; allocation failures preserve old bytes and release ownership. |
| ZIT-045 | `src/text/semantics.zig`, `ZIT-045` | Reverse endpoints normalize, empty ranges have length zero, invalid ranges fail, positions order by line then byte column. The next rows also reject offsets splitting UTF-8 scalars. |
| ZIT-046 | `src/text/document.zig`, `ZIT-046` | Unordered original-coordinate batches commit once; overlap, invalid UTF-8/boundaries and version overflow preserve state. Adjacent edits with snapshot input yield `XYabcc` from `abc`. |
| ZIT-047 | `src/text/document.zig`, `ZIT-047` | Snapshots retain bytes/version after edits and document destruction; release cannot invalidate an active document; snapshot allocation failures leak nothing. |
| ZIT-048 | `src/text/document.zig`, `ZIT-048` | Empty, mixed-ending, multibyte and split-piece CRLF positions match the reference; invalid lines/columns fail before access. |
| ZIT-049 | `src/text/document.zig`, `ZIT-049` | LF, CRLF, lone CR, mixed endings, BOM and missing final newline remain exact; invalid UTF-8 is rejected without replacement. |
| ZIT-051 compaction | `src/text/document.zig`, `ZIT-051` | Paste/delete reclaims dead insertion history transactionally; every injected allocation failure preserves content, version, metadata, index and snapshots. |

Run ZIT-050 and the complete production contracts together:

```sh
zig build production-text-test -Doptimize=ReleaseSafe -j1 --summary all \
  --cache-dir "$ZIT_TEXT_TEST_DIR/cache" \
  --global-cache-dir "$ZIT_TEXT_TEST_DIR/global-cache"
```

Expected: all production tests pass. Coverage includes 32 fixed seeds × 512 atomic
batches, retained snapshots, valid/invalid positions, metadata, mixed-ending suffix
updates and fragmented 65,536-byte long lines. The retained seed
`0x5a4954044051`, prefix 26, must preserve earlier line starts after editing a later
line. On failure, retain the printed seed/prefix, command and log; do not change
validation rules or expected content to make the test pass.

## ZIT-051 measurements (UNRUN BY OPERATOR)

Run each measurement separately, with ordinary user workloads paused if practical:

```sh
zig build production-text-benchmark -Doptimize=ReleaseFast -j1 --summary all \
  --cache-dir "$ZIT_TEXT_TEST_DIR/cache" \
  --global-cache-dir "$ZIT_TEXT_TEST_DIR/global-cache" \
  -- "$ZIT_TEXT_TEST_DIR/run1.csv"
zig build production-text-summary -Doptimize=ReleaseFast -j1 \
  --cache-dir "$ZIT_TEXT_TEST_DIR/cache" \
  --global-cache-dir "$ZIT_TEXT_TEST_DIR/global-cache" \
  -- "$ZIT_TEXT_TEST_DIR/run1.csv" "$ZIT_TEXT_TEST_DIR/summary1.csv" --check-budgets
```

Repeat these two commands with `run2.csv` and `summary2.csv`. Expected: all five
fixtures complete; each raw file has **7,330 data rows plus one header**; each
summary validates **85 groups**, including expected sample counts, correct fixture
sizes and model label. No accounting leak or content mismatch is accepted.

[Budget proposals and retained agent measurements](../src/text/production-budgets.md)
explain p95 versus maxima and requested bytes versus RSS. New proposed gates are
50 ms open p95, 16 ms edit/batch/sustained/churn p95, 10 ms snapshot p95, 10 µs
lookup p95 and peak requested bytes ≤ `8 × fixture bytes + 512 KiB`, including
four held snapshots. Record hardware, OS, Zig version, mode and host activity.
If a gate misses, preserve evidence and report it; do not raise a threshold silently.
**Maintainer acceptance of these proposed thresholds is still outstanding.**

## PR checkpoint (UNRUN BY OPERATOR)

```sh
zig build check -Doptimize=ReleaseSafe -j1 --summary all \
  --cache-dir "$ZIT_TEXT_TEST_DIR/cache" \
  --global-cache-dir "$ZIT_TEXT_TEST_DIR/global-cache"
```

Expected: all repository tests, negative module-boundary fixtures, formatting,
links and trace checks pass. The repository's commit hook independently invokes
`zig build check` in its default mode and can compile additional artifacts. Do
not disable it. The publication workflow runs this same complete check target with a task-local
serial launcher; the repository hook remains unchanged. Hosted CI must be checked
on the exact published head. No manual operator acceptance is implied.

## Cleanup and handoff

- Keep raw CSV, summaries and any failing logs in the printed temporary directory
  until reviewed. No benchmark output belongs in tracked `docs/milestones`.
- Stop only a process you started; this checklist does not start background services
  or sleep prevention. The agent's own tracked caffeinate process was stopped.
- To remove generated test data later, inspect the exact printed directory in
  Finder and move only that directory to Trash after preserving evidence. Never
  delete the task worktree, other task caches, project files or broad `/tmp` paths.
- `unset ZIT_TEXT_TEST_DIR` clears the shell variable; no system setting was changed.
- Record date, source commit/dirty state, commands, pass/fail, evidence paths and
  explicit unrun cases in your review. Existing historical ledger files are
  write-once; add a new record for later results rather than editing old records.

## Existing agent evidence and remaining acceptance

Before the pause, the latest ReleaseSafe repository checkpoint passed **42/42
steps and 86/86 tests**, including production, integration and boundary fixtures.
Two final ReleaseFast target-Mac measurements passed all proposed gates; raw data
is retained in the task worktree's ignored `.zig-cache/`. Those observations do
not mean the operator steps above ran.

Manual editor journeys, file save/recovery, DVUI rendering/input, physical IME,
VoiceOver and live-provider checks remain **UNRUN for this batch**, and are owned
by their existing tickets. Coverage-guided fuzzing remains a separately documented
pinned-runner limitation. See [follow-ups](production-text-follow-ups.md).
