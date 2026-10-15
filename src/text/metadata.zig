//! Bytes are never decoded with replacement, stripped, or normalized.
const Storage = @import("storage.zig").Storage;
pub const Endings = enum { none, lf, crlf, cr, mixed };
pub const Counts = struct {
    lf: usize = 0,
    crlf: usize = 0,
    cr: usize = 0,
    pub fn scan(storage: *const Storage, start: usize, end: usize) Counts {
        var result: Counts = .{};
        var cr = false;
        var chunks = storage.chunks(start, end);
        while (chunks.next()) |bytes| for (bytes) |byte| {
            if (cr) {
                if (byte == '\n') result.crlf += 1 else result.cr += 1;
            } else if (byte == '\n') result.lf += 1;
            cr = byte == '\r';
        };
        if (cr) result.cr += 1;
        return result;
    }
    pub fn form(self: Counts) Endings {
        const kinds = @as(u8, @intFromBool(self.lf > 0)) + @as(u8, @intFromBool(self.crlf > 0)) + @as(u8, @intFromBool(self.cr > 0));
        if (kinds > 1) return .mixed;
        if (self.lf > 0) return .lf;
        if (self.crlf > 0) return .crlf;
        if (self.cr > 0) return .cr;
        return .none;
    }
};
pub const Metadata = struct {
    /// Invalid UTF-8 is rejected before construction or mutation, preserving input
    /// at the caller. The file adapter owns unsupported-encoding decisions.
    decoding: enum { valid_utf8 } = .valid_utf8,
    utf8_bom: bool,
    endings: Endings,
    final_newline: bool,

    pub fn from(storage: *const Storage, counts: Counts) Metadata {
        return .{
            .utf8_bom = storage.len() >= 3 and storage.byteAt(0) == 0xef and storage.byteAt(1) == 0xbb and storage.byteAt(2) == 0xbf,
            .endings = counts.form(),
            .final_newline = storage.len() > 0 and (storage.byteAt(storage.len() - 1) == '\r' or storage.byteAt(storage.len() - 1) == '\n'),
        };
    }
};
