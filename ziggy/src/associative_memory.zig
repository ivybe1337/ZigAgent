const std = @import("std");
const sys = @import("sys.zig");

pub const AssociativeMemoryVault = struct {
    allocator: std.mem.Allocator,
    storage_path: [512]u8,
    storage_path_len: usize,

    pub fn init(allocator: std.mem.Allocator, storage_dir: []const u8) AssociativeMemoryVault {
        var self = AssociativeMemoryVault{
            .allocator = allocator,
            .storage_path = [_]u8{0} ** 512,
            .storage_path_len = 0,
        };
        const p = std.fmt.bufPrint(&self.storage_path, "{s}/associative_vault.jsonl", .{storage_dir}) catch ".ziggy/associative_vault.jsonl";
        self.storage_path_len = p.len;
        return self;
    }

    pub fn storeMemory(self: *AssociativeMemoryVault, tag: []const u8, content: []const u8) void {
        var json_buf: [2048]u8 = undefined;
        const entry = std.fmt.bufPrint(
            &json_buf,
            "{{\"tag\":\"{s}\",\"content\":\"{s}\",\"timestamp\":{d}}}\n",
            .{ tag, content, sys.currentTimestamp() },
        ) catch return;

        const path = self.storage_path[0..self.storage_path_len];
        const file_handle = sys.Sys.open(@ptrCast(path.ptr), sys.O_WRONLY | sys.O_CREAT | sys.O_APPEND, @as(c_uint, 0o644));
        if (file_handle >= 0) {
            _ = sys.Sys.write(file_handle, entry.ptr, entry.len);
            _ = sys.Sys.close(file_handle);
        }
    }

    pub fn matchContext(self: *AssociativeMemoryVault, text: []const u8, buffer: []u8) usize {
        const path = self.storage_path[0..self.storage_path_len];
        const content = sys.readEntireFile(self.allocator, path, 65536) orelse return 0;
        defer self.allocator.free(content);

        var cursor: usize = 0;
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            // Check if line tag appears in input text
            if (std.mem.indexOf(u8, line, "\"tag\":\"")) |tag_start| {
                const s = tag_start + 7;
                if (std.mem.indexOfScalar(u8, line[s..], '"')) |tag_end| {
                    const tag = line[s .. s + tag_end];
                    if (std.mem.indexOf(u8, text, tag) != null) {
                        const formatted = std.fmt.bufPrint(
                            buffer[cursor..],
                            " • [Flagged Context: {s}] {s}\n",
                            .{ tag, line },
                        ) catch break;
                        cursor += formatted.len;
                    }
                }
            }
        }
        return cursor;
    }
};
