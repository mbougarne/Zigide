# Data, Safety, and Operations

## Local Data

Initial persistent data is local and human-inspectable:

| Data | Initial format | Write policy |
| --- | --- | --- |
| User settings | JSON | validate, write temp file, sync, atomic rename |
| Keybindings | JSON | validate, write temp file, sync, atomic rename |
| Workspace state | versioned JSON | atomic replace |
| Recovery snapshots | versioned files plus manifest | periodic and on focus loss |
| Logs | bounded UTF-8 text or JSON Lines | rotate by size and count |
| Extension manifests | JSON | read-only validation |

SQLite or another database should be introduced only when transactional or query needs exceed these files.

## Recovery

Dirty documents receive recovery snapshots outside the workspace. A snapshot records resource identity, base file metadata, document version, encoding, line ending, and content checksum. On clean save or explicit discard, the matching snapshot is removed.

Recovery must never overwrite a newer workspace file automatically. Startup presents a restore decision when the disk file and snapshot diverge.

## Security Boundaries

Inputs that cross a trust boundary include workspace files, filenames, extension manifests and messages, LSP messages, task output, settings, and trace records.

Required controls:

* Bound message, file-preview, and log-entry sizes.
* Validate protocol shapes before dispatch.
* Avoid shell interpolation; spawn executables with argument arrays.
* Normalize paths and define symlink behavior before enforcing workspace boundaries.
* Redact secrets and sensitive environment values from logs and public traces.
* Never execute workspace tasks or extensions silently on folder open.
* Display the executable and working directory before first task execution.

The first release is local-first but not a hostile-code sandbox. Documentation and UI must state this plainly.

## Observability

Structured logs include timestamp, severity, subsystem, event name, correlation ID, and safe fields. Document contents, prompts, tokens, environment dumps, and full protocol payloads are excluded by default.

Debug logging is opt-in and still applies redaction. Logging failure must not crash editing or corrupt user data.

No product telemetry is required for the initial release. If telemetry is proposed later, it requires an ADR covering consent, collection, retention, deletion, and public schema.

## Public Development Trace

The `agents/` records are repository development artifacts, not runtime IDE logs. Before publication they must be checked for secrets, personal data, proprietary instructions, and redistribution rights.

Git remains the authoritative history of file changes. Conversation records explain intent and outcome; they do not replace commits, reviews, tests, or release notes.

## Verification Strategy

The architecture expects several levels of evidence:

* Unit tests for text invariants, command dispatch, parsers, and state transitions.
* Property and fuzz tests for text edits, UTF-8 boundaries, framing, manifests, and protocol decoding.
* Integration tests with real temporary files, ZLS, and extension fixtures.
* Crash-recovery tests that terminate the process during writes.
* Golden tests only for stable serialized contracts, with intentional update review.
* Performance benchmarks for startup, large-file open, edit latency, search, and memory.

CI should eventually test formatting, static analysis available in the Zig toolchain, unit/integration suites, and supported platform builds. Local claims must name the exact checks run.
