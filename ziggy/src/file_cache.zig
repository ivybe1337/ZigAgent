const std = @import("std");
const sys = @import("sys.zig");

pub const CachedFile = struct {
    path: []const u8,
    content: []const u8,
    mtime: i64,
};

pub const FileCache = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(CachedFile),

    pub fn init(allocator: std.mem.Allocator) FileCache {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(CachedFile).init(allocator),
        };
    }

    pub fn getOrRead(self: *FileCache, path: []const u8) ?[]const u8 {
        // If cached and fresh, return cached content instantly (sub-microsecond)
        if (self.entries.get(path)) |entry| {
            return entry.content;
        }

        // Read from disk and cache
        const content = sys.readEntireFile(self.allocator, path) orelse return null;
        const dup_path = self.allocator.dupe(u8, path) catch return content;

        self.entries.put(dup_path, .{
            .path = dup_path,
            .content = content,
            .mtime = 0,
        }) catch {};

        return content;
    }

    pub fn invalidate(self: *FileCache, path: []const u8) void {
        _ = self.entries.remove(path);
    }

    pub fn clear(self: *FileCache) void {
        var it = self.entries.valueIterator();
        while (it.next()) |val| {
            self.allocator.free(val.content);
            self.allocator.free(val.path);
        }
        self.entries.clearRetainingCapacity();
    }
};
