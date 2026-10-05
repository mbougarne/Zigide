# Foundation Primitives

Foundation supplies small values and explicit borrowed interfaces. It imports no product module and owns no product workflow. The production clock lives in [the adapters module](../adapters/clock.zig); the deterministic clock stays in foundation.

## Ownership and concurrency

| API | Allocator and lifetime | Thread contract |
| --- | --- | --- |
| `ids.Generator(Id)` | Caller owns the value; no allocator or deinit. Use one sequence per domain per application session. Seeds permit deterministic tests; exhaustion returns `IdExhausted` without wrapping. IDs are not globally unique, persisted IDs, or protocol identifiers. | Application thread; synchronize externally if shared. |
| `clock.Clock` | Borrows its context, which must remain at a stable address until all calls finish. Wall timestamps and monotonic timestamps have different types. | Depends on the implementation. |
| `clock.ManualClock` | Caller owns the value; no allocator or deinit. `advance` changes both clocks atomically with respect to overflow; wall time can be corrected independently. | Application/test thread. |
| `adapters.SystemClock` | Borrows the I/O runtime; runtime and adapter outlive the clock interface. No adapter allocation/deinit. Uses Unix epoch wall time and monotonic awake time. | Read-only calls through the runtime. |
| `cancellation.Source` / `Token` | Source owns inline atomic state. Tokens borrow it. Keep source address stable, signal on abandonment, join observers before source scope ends. Neither type allocates or needs deinit. Cancellation is not worker termination or result validation. | Signal/observe across threads; release/acquire ordering. |
| `events.Event(Payload)` | `init(allocator)` owns subscription nodes and successfully transferred callback contexts. `deinit` frees them once. A failed subscribe leaves context with the caller. `destroy` receives the emitter allocator; use it for owned context allocation, or provide a no-op for explicitly borrowed context that outlives the subscription. | Application thread only; synchronous callbacks. |
| `Event.Subscription` | Borrowed emitter + unique ID, no allocation. Dispose before emitter deinit; repeat/copy disposal is safe while emitter lives. The emitter must remain at a stable address. Handles do not extend its lifetime. | Same thread as emitter. |
| `errors.Failure` | Copyable category, operation and typed identities; no allocator/deinit. Preserve the concrete Zig error union separately. Resolve private resource details in the owning service, never the log schema. | Immutable values can be passed to workers. |
| `logging.Logger` / `Sink` | Logger borrows clock/sink contexts. A sink that retains events copies values and owns its storage/cleanup; sink calls are synchronous. No logger allocation/deinit. A write failure returns false without propagating into editing. | Application thread unless the sink explicitly provides synchronization. |

## Event dispatch contract

Handlers run in subscription order. Removal takes effect immediately, including removal of a handler that has not run yet. New handlers are excluded from the current dispatch and included in the next dispatch, including a nested dispatch. Callback destruction is deferred until the outermost dispatch returns, keeping active callback contexts alive after self-disposal. Payloads are borrowed only during each callback.

Cleanup callbacks must not reenter the emitter. Do not deinitialize the emitter from a handler. A borrowed callback context must outlive its subscription and any active dispatch; owned contexts are released by `destroy`. No hidden global event bus, worker scheduling, or locking is provided.

## Safe errors and logging

At a boundary, map a concrete Zig error to a `Failure` and preserve that metadata as it propagates. The UI message is fixed by category. Operation/resource IDs preserve context without exposing file paths or document contents.

Every log event contains wall timestamp, severity, subsystem, event name and correlation ID, plus optional safe failure metadata. Subsystem/event names are enums, and the schema has no arbitrary string, payload, token, prompt, environment, or protocol dump field. Debug events are disabled by default and use the same bounded schema when enabled. Add new schema fields deliberately with a privacy review. Storage, serialization, rotation and UI presentation belong to later adapters/services.

## Verification

`zig build unit-test` runs the foundation and adapter test roots explicitly, plus a compile-failure fixture proving operation IDs cannot be assigned to correlation IDs. `zig build check` adds repository hygiene, trace/link validation, integration, formatting and the existing dependency-boundary fixture.

Tests use `std.testing.allocator` and `std.testing.checkAllAllocationFailures` for every allocation point in event registration and request success/failure/cancellation/abandonment. They exercise ordering, repeat disposal, removal during dispatch, self-disposal, nested dispatch, new subscriptions, exhaustion, emitter cleanup, deterministic time, safe context propagation, sink replacement/failure and cross-thread cancellation. No test sleeps or mutates global clock/ID state.
