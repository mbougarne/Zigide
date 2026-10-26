# Safe File I/O review guide (ZIT-064–070)

## Entry points and ownership

`application.Workspace.files` accepts the UI-neutral `ports.SafeFiles` service.
`openFile`, `saveFile` and `resolveExternal` implement local text persistence.
The existing byte-fed `openDocument` remains useful for headless callers; it has
no disk baseline and therefore cannot overwrite an existing file through this service.
The executable still has no production editor UI; these are headless application
flows for the later DVUI integration.

Review the port in `src/ports/module.zig`, OS operations in
`src/adapters/safe_files.zig`, orchestration in `src/application/workspace.zig`,
and `Session.persist` / `Session.reload` in `src/workspace/session.zig`.
The session holds its mutation guard over persistence, allocates its replacement
identity and immutable saved snapshot before calling the writer, and commits
without another allocation. Failed saves retain the identity, edits, selection,
undo history and saved baseline. Reload prepares the entire replacement first.

## File policy

- Default maximum: 16 MiB, configurable by the composition owner. File size is
  checked before reading; reads use 4 KiB chunks, enforce the limit even if the
  file grows, and compare descriptor and pathname metadata after reading.
  A nonblocking, no-follow descriptor prevents FIFO hangs and leaf-link races.
- Existing paths are physically resolved before workspace admission. New names
  resolve their existing parent physically. Save As stays inside the current
  workspace and is create-only. Existing destinations, including symlinks, are
  collisions; atomic nonreplacing rename protects against concurrent creation.
- UTF-8 is validated before editable admission and again at persistence. Invalid
  input is rejected, leaving its source untouched. There is no replacement
  decoding, encoding conversion, BOM stripping or line-ending normalization.
  An invalid external revision can be kept on disk while edits are recovered
  with Save As; it cannot be reloaded or overwritten by the text-only workflow.
- Replacement uses an exclusive random sibling temporary file, initially 0600,
  bounded complete writes, permissions, file sync, a second conflict check and
  same-directory atomic rename. No user file is truncated. Temporary files are
  removed on ordinary failure; process termination can leave an orphan sibling.
- macOS permission policy: new files use 0600 subject to umask; replacement keeps
  ordinary rwx mode bits (including executable bits), clears special mode bits,
  and requires destination write access. Read-only files are rejected even when
  directory rename rights would permit replacement. Hard-linked files are
  rejected to avoid silently splitting aliases. The macOS adapter uses `fcopyfile(COPYFILE_METADATA)` to copy stat/security
  metadata, ACLs and extended attributes (including resource forks) before sync.
  The replacement mtime is refreshed after copying, so incremental tools see
  edited content. Metadata-copy errors abort replacement. Xattrs/resource forks are tested;
  custom ACL and ownership cases remain unqualified. Other platforms reject
  replacement until a metadata-preserving adapter is supplied.

## Conflicts, failure context and recovery

The baseline compares inode, size, nanosecond mtime/ctime and mode at the same
canonical path. Edits, deletion and replacement are rejected before overwrite.
Metadata comparison can yield false positives for metadata-only changes. It is
not a checksum or an atomic compare-and-swap: timestamp granularity, inode reuse,
network filesystems and an external writer in the final check-to-rename interval
can cause false negatives. Workspace paths are not hostile-process capabilities;
parent-directory replacement and mount changes are outside this guarantee.

An `ExternalChange` error lets the UI offer reload, inspect, overwrite or cancel.
Cancel changes neither side. Inspect returns owned validated disk bytes without
mutating the document. Reload of a dirty document requires the separate
`discard_dirty` confirmation; invalid input and allocation failure precede mutation.
Overwrite is explicit consent to replace the freshly observed revision, and still
checks that revision again at save time. If the file was deleted or became invalid
UTF-8, Save As provides a nondestructive recovery path.

`LocalFiles.last_failure` records the failing stage, cause and whether rename
already committed. A metadata failure after rename honestly reports `committed`;
the dirty buffer remains available. A retry detects divergence; inspect followed
by explicit overwrite or reload reconciles it. Application failures name the
operation without logging file contents.

## Evidence mapped to acceptance criteria

Run `zig build safe-file-io-test -j2 --summary all`. These disposable fixtures are
also part of `integration-test` and the required `check` target. Tests use the
Zig testing allocator and assert exact disk and buffer bytes, dirty state,
identity and temporary-file cleanup, rather than only successful return values.

| Ticket | Observable evidence in `tests/safe_file_io.zig` |
| --- | --- |
| ZIT-064 | Missing, directory, actual unreadable mode-000 file and oversized input produce distinct failures; no document is admitted. The adapter independently rejects a directory. |
| ZIT-065 | Invalid UTF-8 stays byte-exact on disk and never enters an editable document; invalid external reload retains dirty edits and recovers through Save As. |
| ZIT-066 | Failures at create, second write (after a real 4096-byte partial temp write), permissions, sync and rename retain the original and 9000 dirty bytes; removing the fault permits retry and a second clean save. |
| ZIT-067 | Existing file and symlink collisions, injected access denial and actual read-only destination retain state; successful Save As changes identity only after replacement, leaves source intact, creates 0600 and preserves 0640 on a later save. A concurrent destination creation survives. Native metadata copying retains a synthetic extended attribute and resource fork. |
| ZIT-068 | Same-path edits, same-size inode replacement, deletion, permission changes and an edit during save preparation all conflict before overwrite. |
| ZIT-069 | Cancel and inspect preserve state; dirty reload without separate confirmation fails; confirmed reload and explicit overwrite reconcile state. |
| ZIT-070 | All precommit faults preserve original and dirty bytes and clean temps; a postcommit metadata fault reports committed state, retains edits and recovers explicitly. Empty, BOM, LF, CRLF, CR, mixed, no-final-newline and multilingual bytes round-trip exactly. |

## Validation limits

Local execution uses Zig 0.16.0 on macOS arm64 with disposable fixtures on the
external-storage volume. File sync and atomic rename are exercised; no directory
sync, macOS F_FULLFSYNC, power-loss persistence or hardware cache guarantee is
claimed. Injected sync/rename failures test handling, not physical disk exhaustion
or a failing device. No real user files, cloud data, stress workload, IME or native
permission dialog is used. Filesystem type could not be identified from the
sandbox's DiskManagement framework, so this is evidence for the mounted local
volume, not certification for APFS, network or removable filesystems generally.
