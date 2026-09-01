const std = @import("std");
const sys = @import("sys.zig");

pub const ContextLedger = struct {
    allocator: std.mem.Allocator,
    ledger_path: [512]u8,
    ledger_path_len: usize,
    current_agent_id: [32]u8,
    current_project_id: [32]u8,
    current_session_id: [32]u8,

    pub fn init(allocator: std.mem.Allocator, storage_dir: []const u8) ContextLedger {
        var self = ContextLedger{
            .allocator = allocator,
            .ledger_path = [_]u8{0} ** 512,
            .ledger_path_len = 0,
            .current_agent_id = [_]u8{0} ** 32,
            .current_project_id = [_]u8{0} ** 32,
            .current_session_id = [_]u8{0} ** 32,
        };

        const path = std.fmt.bufPrint(&self.ledger_path, "{s}/context_ledger.jsonl", .{storage_dir}) catch ".ziggy/context_ledger.jsonl";
        self.ledger_path_len = path.len;

        // Auto-bootstrap IDs
        const ts = sys.currentTimestamp();
        _ = std.fmt.bufPrint(&self.current_agent_id, "agent-{d}", .{@rem(ts, 100000)}) catch "";
        _ = std.fmt.bufPrint(&self.current_project_id, "project-zigagent", .{}) catch "";
        _ = std.fmt.bufPrint(&self.current_session_id, "sess-{d}", .{@rem(@divTrunc(ts, 10), 100000)}) catch "";

        return self;
    }

    pub fn appendEntry(
        self: *ContextLedger,
        modified_files: []const u8,
        invariants: []const u8,
        decisions: []const u8,
        handoff: []const u8,
    ) void {
        var json_buf: [2048]u8 = undefined;
        const entry_json = std.fmt.bufPrint(
            &json_buf,
            "{{\"timestamp\":{d},\"agent_id\":\"{s}\",\"project_id\":\"{s}\",\"session_id\":\"{s}\",\"modified_files\":\"{s}\",\"invariants\":\"{s}\",\"decisions\":\"{s}\",\"handoff\":\"{s}\"}}\n",
            .{
                sys.currentTimestamp(),
                std.mem.sliceTo(&self.current_agent_id, 0),
                std.mem.sliceTo(&self.current_project_id, 0),
                std.mem.sliceTo(&self.current_session_id, 0),
                modified_files,
                invariants,
                decisions,
                handoff,
            },
        ) catch return;

        const path = self.ledger_path[0..self.ledger_path_len];
        const file_handle = sys.Sys.open(@ptrCast(path.ptr), sys.O_WRONLY | sys.O_CREAT | sys.O_APPEND, @as(c_uint, 0o644));
        if (file_handle >= 0) {
            _ = sys.Sys.write(file_handle, entry_json.ptr, entry_json.len);
            _ = sys.Sys.close(file_handle);
        }
    }

    pub fn getLatestHandoff(self: *ContextLedger, buffer: []u8) usize {
        const path = self.ledger_path[0..self.ledger_path_len];
        const content = sys.readEntireFile(self.allocator, path, 65536) orelse return 0;
        defer self.allocator.free(content);

        if (content.len == 0) return 0;
        var last_line = content;
        if (std.mem.lastIndexOfScalar(u8, content[0 .. content.len - 1], '\n')) |idx| {
            last_line = content[idx + 1 ..];
        }

        const len = @min(last_line.len, buffer.len);
        @memcpy(buffer[0..len], last_line[0..len]);
        return len;
    }
};
