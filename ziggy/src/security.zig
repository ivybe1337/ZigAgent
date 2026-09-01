const std = @import("std");
const sys = @import("sys.zig");

pub const SecurityAuditResult = struct {
    is_safe: bool,
    violation_reason: []const u8,
};

pub const SecurityEngine = struct {
    pub fn auditCommand(cmd: []const u8) SecurityAuditResult {
        const dangerous_patterns = [_][]const u8{
            "rm -rf /",
            "rm -rf ~",
            "mkfs",
            ":(){ :|:& };:",
            "dd if=/dev/zero",
            "chmod -R 777 /",
            "> /dev/sda",
        };

        for (dangerous_patterns) |pattern| {
            if (std.mem.indexOf(u8, cmd, pattern) != null) {
                return .{
                    .is_safe = false,
                    .violation_reason = "Blocked hazardous destructive command pattern.",
                };
            }
        }

        return .{ .is_safe = true, .violation_reason = "" };
    }

    pub fn sanitizePath(path: []const u8) SecurityAuditResult {
        if (std.mem.indexOf(u8, path, "..") != null and std.mem.indexOf(u8, path, "/etc") != null) {
            return .{
                .is_safe = false,
                .violation_reason = "Path traversal into system root directory blocked.",
            };
        }
        return .{ .is_safe = true, .violation_reason = "" };
    }

    pub fn redactSecrets(input: []const u8, out_buf: []u8) usize {
        var cursor: usize = 0;
        var i: usize = 0;

        while (i < input.len and cursor < out_buf.len - 1) {
            if (std.mem.startsWith(u8, input[i..], "gsk_") or std.mem.startsWith(u8, input[i..], "sk-or-v1-")) {
                const prefix_len: usize = if (std.mem.startsWith(u8, input[i..], "gsk_")) 4 else 9;
                const mask = "[REDACTED_API_KEY]";
                const m_len = @min(mask.len, out_buf.len - 1 - cursor);
                @memcpy(out_buf[cursor .. cursor + m_len], mask[0..m_len]);
                cursor += m_len;

                // Skip remainder of key
                i += prefix_len;
                while (i < input.len and input[i] != ' ' and input[i] != '\n' and input[i] != '"' and input[i] != '\'') {
                    i += 1;
                }
                continue;
            }

            out_buf[cursor] = input[i];
            cursor += 1;
            i += 1;
        }

        out_buf[cursor] = 0;
        return cursor;
    }
};
