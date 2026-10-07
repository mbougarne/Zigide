# Headless application composition

`Context.init(allocator, external)` directly constructs the command registry and
structured logger. `ExternalPorts` requires the clock and log sink explicitly;
there are no defaults, service locator, global instance, or adapter imports.
The executable composition root selects `SystemClock` and the explicit
`DiscardLog` sink. Test roots supply a manual clock and capturing/failing sink.

The context owns only registry storage. Its allocator, external port contexts,
and registered handler contexts are borrowed and must outlive their use. Keep
contexts at stable addresses once borrowed, do not copy an owning context, and
call `deinit` once when service calls have finished. Releasing the context never
releases borrowed adapters. Mutable application state belongs to one thread.

These are the only external dependencies consumed by the current application.
File, storage, process, clipboard, watcher, and UI scheduling interfaces are not
yet implemented. Add explicit fields when their owning tickets introduce real
operations; do not hide concrete adapters behind application defaults. The full
ADR-0001 file/process/UI substitution evidence and reusable test-double suite
remain with ZIT-019. Ordered, idempotent shutdown remains with ZIT-018.

## Commands

The context exposes `commands.register(id, handler)` and `commands.lookup(id)`.
Registration copies ID bytes, borrows the handler context, and returns
`InvalidCommandId`, `DuplicateCommand`, or `OutOfMemory` without replacing an
existing handler. Lookup returns `UnknownCommand` for any absent ID and returns
handlers by value so later map growth cannot invalidate a resolved handler.

IDs are case-sensitive ASCII dot-separated segments, with at least a namespace
and action (for example `zigide.file.open`). Each segment starts with a letter;
later characters may be letters, digits, underscores, or hyphens. No trimming,
case folding, or aliases occur. Registration order has no lookup significance.
Callers choose stable names; this internal API is not an extension wire schema.

The present handler is a borrowed context plus a synchronous no-argument function
returning a Zig error union. Registration and lookup never invoke it. Typed
arguments, preconditions, dispatch error classification, and results remain with
ZIT-016. Per-registration ownership/disposal remains with ZIT-017; there is no
unregister or concurrent dispatch contract in this batch. Resolved copies do not
keep handler contexts alive.

`zig build unit-test` runs registry order, identity, invalid-ID, owned-byte,
map-growth, and exhaustive allocation-failure tests. `zig build integration-test`
composes a service with substituted clock/logging ports, checks separate context
registries and borrowed-port survival, and starts the real executable in an
empty temporary workspace with an empty environment.
