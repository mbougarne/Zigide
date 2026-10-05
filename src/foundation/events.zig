const std = @import("std");

/// Synchronous, application-thread-only events in subscription order. Each
/// successful subscribe transfers callback context ownership to the emitter.
/// Context cleanup waits until the outermost dispatch returns, so self-disposal
/// and nested dispatch cannot free a running callback. Cleanup functions must
/// not reenter the emitter. Keep the emitter at a stable address, dispose handles
/// before deinit, and call deinit exactly once outside dispatch.
pub fn Event(comptime Payload: type) type {
    return struct {
        allocator: std.mem.Allocator,
        first: ?*Node = null,
        last: ?*Node = null,
        next_id: ?u64 = 1,
        depth: usize = 0,
        cleaning: bool = false,
        const Self = @This();
        const Node = struct {
            id: u64,
            active: bool = true,
            next: ?*Node = null,
            callback: Callback,
        };

        pub const Callback = struct {
            context: *anyopaque,
            call: *const fn (*anyopaque, Payload) void,
            /// Frees owned context using the allocator supplied to init.
            destroy: *const fn (*anyopaque, std.mem.Allocator) void,
        };

        /// Borrowed handle, safe to dispose repeatedly or through copies while
        /// the emitter lives. It does not keep the emitter alive.
        pub const Subscription = struct {
            emitter: *Self,
            id: u64,

            pub fn dispose(self: Subscription) void {
                std.debug.assert(!self.emitter.cleaning);
                var node = self.emitter.first;
                while (node) |current| : (node = current.next) {
                    if (current.id == self.id) {
                        current.active = false;
                        break;
                    }
                }
                if (self.emitter.depth == 0) self.emitter.collect();
            }
        };

        /// Owns nodes and transferred callback contexts using this allocator.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// On failure, callback context remains owned by the caller.
        pub fn subscribe(self: *Self, callback: Callback) error{ OutOfMemory, IdExhausted }!Subscription {
            std.debug.assert(!self.cleaning);
            const id = self.next_id orelse return error.IdExhausted;
            const node = try self.allocator.create(Node);
            node.* = .{ .id = id, .callback = callback };
            self.next_id = if (id == std.math.maxInt(u64)) null else id + 1;
            if (self.last) |last| last.next = node else self.first = node;
            self.last = node;
            return .{ .emitter = self, .id = id };
        }

        /// Subscribers added during a dispatch start with the next dispatch
        /// (including nested dispatch). Removed subscribers are skipped at once.
        /// Payload is borrowed for the duration of the callback only.
        pub fn dispatch(self: *Self, payload: Payload) void {
            std.debug.assert(!self.cleaning);
            const end = self.last orelse return;
            self.depth += 1;
            defer {
                self.depth -= 1;
                if (self.depth == 0) self.collect();
            }
            var node = self.first;
            while (node) |current| : (node = current.next) {
                if (current.active) current.callback.call(current.callback.context, payload);
                if (current == end) break;
            }
        }

        pub fn deinit(self: *Self) void {
            std.debug.assert(self.depth == 0 and !self.cleaning);
            var node = self.first;
            while (node) |current| : (node = current.next) current.active = false;
            self.collect();
            self.* = undefined;
        }

        fn collect(self: *Self) void {
            self.cleaning = true;
            defer self.cleaning = false;
            var link = &self.first;
            self.last = null;
            while (link.*) |node| {
                if (node.active) {
                    self.last = node;
                    link = &node.next;
                } else {
                    link.* = node.next;
                    node.callback.destroy(node.callback.context, self.allocator);
                    self.allocator.destroy(node);
                }
            }
        }
    };
}
