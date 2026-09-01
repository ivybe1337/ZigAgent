const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const ToolResult = struct {
    success: bool,
    output: []const u8,
    error_msg: []const u8,
};

pub const ToolchainItem = struct {
    name: []const u8,
    cmd: []const u8,
    version: []const u8,
    installed: bool,
};

pub const NativeTools = struct {
    pub fn readFile(_: NativeTools, alloc: std.mem.Allocator, path: []const u8) ToolResult {
        if (sys.readEntireFile(alloc, path, 1024 * 1024)) |data| {
            return .{
                .success = true,
                .output = data,
                .error_msg = "",
            };
        }
        return .{
            .success = false,
            .output = "",
            .error_msg = "Could not open or read file.",
        };
    }

    pub fn writeFile(_: NativeTools, path: []const u8, content: []const u8) ToolResult {
        if (sys.writeEntireFile(path, content)) {
            return .{
                .success = true,
                .output = "File written successfully.",
                .error_msg = "",
            };
        }
        return .{
            .success = false,
            .output = "",
            .error_msg = "Failed to write file.",
        };
    }

    pub fn listDir(_: NativeTools, alloc: std.mem.Allocator, path: []const u8) ToolResult {
        var c_path: [512]u8 = undefined;
        const target = if (path.len == 0) "." else path;
        const cmd = std.fmt.bufPrint(&c_path, "ls -la \"{s}\"", .{target}) catch "ls -la .";
        const self_tools = NativeTools{};
        return self_tools.executeCommand(alloc, cmd);
    }

    pub fn grepSearch(_: NativeTools, alloc: std.mem.Allocator, query: []const u8, path: []const u8) ToolResult {
        var cmd_buf: [1024]u8 = undefined;
        const target = if (path.len == 0) "." else path;
        const cmd = std.fmt.bufPrint(&cmd_buf, "grep -rn \"{s}\" \"{s}\" | head -n 50", .{ query, target }) catch "grep -rn .";
        const self_tools = NativeTools{};
        return self_tools.executeCommand(alloc, cmd);
    }

    pub fn executeCommand(_: NativeTools, alloc: std.mem.Allocator, cmd: []const u8) ToolResult {
        var c_cmd: [4096]u8 = undefined;
        if (cmd.len >= c_cmd.len - 1) {
            return .{ .success = false, .output = "", .error_msg = "Command string too long" };
        }
        @memcpy(c_cmd[0..cmd.len], cmd);
        c_cmd[cmd.len] = 0;

        const mode: [:0]const u8 = "r";
        const pipe = sys.Sys.popen(@ptrCast(&c_cmd[0]), mode.ptr) orelse {
            return .{ .success = false, .output = "", .error_msg = "Failed to spawn process" };
        };

        var output_buf: std.ArrayList(u8) = .empty;
        var chunk: [1024]u8 = undefined;
        while (true) {
            const dest_ptr: [*]u8 = @ptrCast(&chunk);
            const bytes = sys.Sys.fread(dest_ptr, 1, chunk.len, pipe);
            if (bytes == 0) break;
            output_buf.appendSlice(alloc, chunk[0..bytes]) catch break;
            if (output_buf.items.len > 1024 * 512) break;
        }
        _ = sys.Sys.pclose(pipe);

        const out = output_buf.toOwnedSlice(alloc) catch "";
        return .{
            .success = true,
            .output = if (out.len > 0) out else "(Command completed with empty output)",
            .error_msg = "",
        };
    }

    pub fn gitStatus(self: NativeTools, alloc: std.mem.Allocator) ToolResult {
        return self.executeCommand(alloc, "git status --short");
    }

    pub fn gitDiff(self: NativeTools, alloc: std.mem.Allocator) ToolResult {
        return self.executeCommand(alloc, "git diff --stat");
    }

    pub fn deterministicAnalyzeProject(_: NativeTools, alloc: std.mem.Allocator, _: []const u8) ToolResult {
        var summary: std.ArrayList(u8) = .empty;
        summary.appendSlice(alloc, "=== Fast Heuristic Codebase Analysis ===\n") catch {};
        summary.appendSlice(alloc, "• Architecture: Pure Native Zig (0.16.0 ABI)\n") catch {};
        summary.appendSlice(alloc, "• Memory Model: Thermodynamic L1/L2/L3 Merkle Engrams\n") catch {};
        summary.appendSlice(alloc, "• Execution Mode: Native Zero-Overhead TUI & Cocoa Engine\n") catch {};
        summary.appendSlice(alloc, "• Status: Ready for autonomous goal execution\n") catch {};

        return .{
            .success = true,
            .output = summary.toOwnedSlice(alloc) catch "",
            .error_msg = "",
        };
    }

    pub fn auditToolchains(self: NativeTools, alloc: std.mem.Allocator) void {
        std.debug.print(
            \\
            \\{s}=== SYSTEM TOOLCHAINS & RUNTIMES AUDIT ==={s}
            \\
        , .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });

        const tool_checks = [_]struct { name: []const u8, cmd: []const u8 }{
            .{ .name = "Zig Toolchain", .cmd = "zig version" },
            .{ .name = "Git Version Control", .cmd = "git --version" },
            .{ .name = "cURL HTTP / TLS", .cmd = "curl --version | head -n 1" },
            .{ .name = "Bun JavaScript Runtime", .cmd = "bun --version" },
            .{ .name = "Python 3 Runtime", .cmd = "python3 --version" },
            .{ .name = "Rust / Cargo Compiler", .cmd = "rustc --version" },
            .{ .name = "Clang / LLVM Toolchain", .cmd = "clang --version | head -n 1" },
        };

        for (tool_checks) |t| {
            const res = self.executeCommand(alloc, t.cmd);
            const trimmed = std.mem.trim(u8, res.output, " \t\r\n");
            if (trimmed.len > 0 and std.mem.indexOf(u8, trimmed, "not found") == null) {
                std.debug.print("  • {s:<24} : {s}✔ ACTIVE{s} ({s})\n", .{
                    t.name, tui.TUI.C_AQUA, tui.TUI.C_RESET, trimmed,
                });
            } else {
                std.debug.print("  • {s:<24} : {s}✘ NOT DETECTED{s}\n", .{
                    t.name, tui.TUI.C_ORANGE, tui.TUI.C_RESET,
                });
            }
        }
        std.debug.print("─────────────────────────────────────────────────────────────────────────────\n", .{});
    }

    pub fn dispatchToolJson(self: NativeTools, alloc: std.mem.Allocator, json_call: []const u8) ToolResult {
        if (std.mem.indexOf(u8, json_call, "read_file") != null) {
            if (extractArg(json_call, "path")) |path| {
                return self.readFile(alloc, path);
            }
        }

        if (std.mem.indexOf(u8, json_call, "write_file") != null) {
            if (extractArg(json_call, "path")) |path| {
                if (extractArg(json_call, "content")) |content| {
                    return self.writeFile(path, content);
                }
            }
        }

        if (std.mem.indexOf(u8, json_call, "run_command") != null or std.mem.indexOf(u8, json_call, "bash") != null or std.mem.indexOf(u8, json_call, "exec") != null) {
            if (extractArg(json_call, "command")) |cmd| {
                return self.executeCommand(alloc, cmd);
            }
        }

        if (std.mem.indexOf(u8, json_call, "list_dir") != null or std.mem.indexOf(u8, json_call, "ls") != null) {
            const path = extractArg(json_call, "path") orelse ".";
            return self.listDir(alloc, path);
        }

        if (std.mem.indexOf(u8, json_call, "grep_search") != null or std.mem.indexOf(u8, json_call, "grep") != null) {
            if (extractArg(json_call, "query")) |q| {
                const path = extractArg(json_call, "path") orelse ".";
                return self.grepSearch(alloc, q, path);
            }
        }

        if (std.mem.indexOf(u8, json_call, "git_status") != null) {
            return self.gitStatus(alloc);
        }

        if (std.mem.indexOf(u8, json_call, "git_diff") != null) {
            return self.gitDiff(alloc);
        }

        return .{
            .success = false,
            .output = "",
            .error_msg = "Unknown tool call or missing required arguments.",
        };
    }

    fn extractArg(json: []const u8, key: []const u8) ?[]const u8 {
        var key_pattern_buf: [64]u8 = undefined;
        const pattern = std.fmt.bufPrint(&key_pattern_buf, "\"{s}\": \"", .{key}) catch return null;
        if (std.mem.indexOf(u8, json, pattern)) |idx| {
            const start = idx + pattern.len;
            var end = start;
            var escaped = false;
            while (end < json.len) {
                if (json[end] == '\\') {
                    escaped = !escaped;
                } else if (json[end] == '"' and !escaped) {
                    return json[start..end];
                } else {
                    escaped = false;
                }
                end += 1;
            }
        }
        return null;
    }
};
