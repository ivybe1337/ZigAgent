const std = @import("std");
const sys = @import("sys.zig");

pub const AgentMessage = struct {
    id: [32]u8,
    timestamp: i64,
    sender_agent: [32]u8,
    sender_project: [32]u8,
    target_project: [32]u8,
    content: []const u8,
};

pub const MailboxManager = struct {
    allocator: std.mem.Allocator,
    base_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, base_dir: []const u8) MailboxManager {
        const self = MailboxManager{
            .allocator = allocator,
            .base_dir = base_dir,
        };
        _ = sys.makeDirAll(base_dir);
        return self;
    }

    pub fn sendMessage(
        self: *MailboxManager,
        sender_agent: []const u8,
        sender_project: []const u8,
        target_project: []const u8,
        content: []const u8,
    ) bool {
        var target_dir_buf: [512]u8 = undefined;
        const target_dir = std.fmt.bufPrint(&target_dir_buf, "{s}/{s}", .{ self.base_dir, target_project }) catch return false;
        _ = sys.makeDirAll(target_dir);

        const ts = sys.currentTimestamp();
        var file_path_buf: [512]u8 = undefined;
        const file_path = std.fmt.bufPrint(&file_path_buf, "{s}/msg_{d}.json", .{ target_dir, ts }) catch return false;

        var json_buf: [2048]u8 = undefined;
        const json = std.fmt.bufPrint(
            &json_buf,
            "{{\"id\":\"msg-{d}\",\"timestamp\":{d},\"sender_agent\":\"{s}\",\"sender_project\":\"{s}\",\"target_project\":\"{s}\",\"content\":\"{s}\"}}\n",
            .{ ts, ts, sender_agent, sender_project, target_project, content },
        ) catch return false;

        return sys.writeEntireFile(file_path, json);
    }

    pub fn fetchInbox(self: *MailboxManager, project_id: []const u8, buffer: []u8) usize {
        var target_dir_buf: [512]u8 = undefined;
        const target_dir = std.fmt.bufPrint(&target_dir_buf, "{s}/{s}", .{ self.base_dir, project_id }) catch return 0;

        const content = sys.readEntireFile(self.allocator, target_dir, 8192);
        if (content) |c| {
            defer self.allocator.free(c);
            const len = @min(c.len, buffer.len);
            @memcpy(buffer[0..len], c[0..len]);
            return len;
        }
        return 0;
    }
};
