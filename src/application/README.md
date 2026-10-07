# Headless application composition

`Context.init(allocator, external)` directly constructs a command registry and
logger from borrowed ports. Only the executable composition root chooses concrete
adapters. Tests supply manual time, log capture, file/storage byte stores, a child
process double, and an explicitly pumped UI queue. Optional ports are absent
capabilities; there is no implicit platform fallback or service locator. Services
requiring a port must check it or receive it explicitly during construction.

The context owns registry storage. The allocator, external contexts, service
slice, and callback contexts are borrowed. Keep them at stable addresses until
shutdown finishes, and keep the registry alive until every registration handle
is discarded. Mutable state, registration, dispatch, and lifecycle operations
belong to the application thread. Workers may signal atomic cancellation but
must marshal lifecycle requests through a scheduling adapter.

## Commands

`commands.register(id, handler)` copies the ID and returns a disposable
`Registration`. IDs are case-sensitive ASCII dot-separated segments, with at
least a namespace and action. Every segment starts with a letter; subsequent
characters may include digits, underscores, and hyphens. Duplicate IDs never
replace a handler. Lookup returns a checked registration identity; it no longer
exposes a callable borrowed handler that could outlive disposal.

`dispatch(id, arguments, token)` and `Registration.dispatch(arguments, token)`
check admission, registration identity, cancellation, argument type, optional
value validation, and optional enablement before invoking the handler. Internal
arguments are tagged `none`, `text`, `integer`, or `boolean` values. Text is
borrowed for the synchronous call. These are not extension wire schemas.

Failures distinguish `UnknownCommand`, `InvalidArguments`, `DisabledCommand`,
`Cancelled`, `HandlerFailed`, and `ShuttingDown`. Non-cancellation handler errors
map to `HandlerFailed`; services retain responsibility for their own contextual
error reporting. Cancellation is cooperative and cannot undo effects already
performed by a handler. Admission and cancellation are rechecked after callbacks.

A registration pins its context during validation, enablement, and handler
execution, including nested dispatch. `dispose()` removes only that registration;
stale handles cannot invoke or remove an ID's replacement. Repeated disposal is
safe while the registry lives. `CommandInUse` means the owner must retry after
dispatch unwinds and must keep the context alive until disposal succeeds.
Callbacks can grow the registry without invalidating active dispatch state.

## Startup and shutdown

`start(services)` starts services in dependency order. Successful repeated startup
is a no-op; commands become available only after startup completes. Each attempted
service, including one that partially failed startup, must support shutdown and
release. Startup failure rolls back attempted services and retains the original
cause. Later services never start after a failure or shutdown request.

The first `shutdown(absolute_monotonic_deadline)` closes command registration and
dispatch immediately. It retains that deadline across retries, then performs:

1. Persist hooks in startup order.
2. Cancellation hooks in startup order.
3. Stop hooks in reverse dependency order.
4. Log-flush hooks in startup order.
5. Nonblocking resource release in reverse dependency order.

Every phase runs despite hook errors. Every attempted service releases once.
The first error is retained; exceeding the deadline produces `DeadlineExceeded`
when there was no earlier failure. Repeated completed shutdown returns the saved
outcome without rerunning hooks. Startup cannot resume a stopped context.

A shutdown requested inside dispatch or another lifecycle callback returns
`Busy` after closing admission. The outer owner must retry once the callback
unwinds; resources are never released beneath a running callback. Call `deinit`
only on a never-started context or after shutdown reaches `stopped`, including
terminal shutdown errors. `deinit` frees only registry storage.

Deadlines are cooperative contracts: hooks receive the same absolute deadline,
must bound waiting, and must force child/worker cleanup on expiry before release.
A synchronous callback cannot be preempted by this application-thread owner.
Production process supervision and persistence remain their owning tickets.

## Headless ports and tests

`ports.BlobStore` serves separate file and storage instances. Reads return
caller-owned allocations; writes copy bytes before returning. `ports.Process`
exposes start, poll, and terminate; `ports.Scheduler` queues borrowed cancellable
callbacks. Request deadlines use monotonic time. `Pending` permits a retry and
has no side effects. Concrete OS behavior is intentionally outside these ports.

Reusable doubles live in `tests/support/ports.zig`. They own their data and argv,
allow expected failures and manual-time delays, and never touch real files,
processes, or UI. The FIFO scheduler pumps a snapshot; reentrant posts wait for
the next pump, and cancelled work is skipped. Each double is application-thread
only and must outlive its borrowed port and queued callbacks.

`zig build check` runs registry, heap-lifetime, lifecycle, allocation-failure,
headless command/port, and real executable smoke tests. The integration executable
path accepts absolute cache paths, allowing task-specific build caches.
