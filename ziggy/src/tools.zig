const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const minds_eye = @import("minds_eye.zig");
const thermodynamic_memory = @import("thermodynamic_memory.zig");
const morphogenetic = @import("morphogenetic.zig");

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
        if (sys.readEntireFile(alloc, path, 1024 * 1024 * 4)) |data| {
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

    pub fn editFile(self: NativeTools, alloc: std.mem.Allocator, path: []const u8, target: []const u8, replacement: []const u8) ToolResult {
        const file_content = sys.readEntireFile(alloc, path, 1024 * 1024 * 4) orelse {
            return .{ .success = false, .output = "", .error_msg = "Target file could not be read." };
        };
        defer alloc.free(file_content);

        const target_idx = std.mem.indexOf(u8, file_content, target) orelse {
            return .{ .success = false, .output = "", .error_msg = "Target content substring was not found in file." };
        };

        var new_content = std.ArrayList(u8).initCapacity(alloc, file_content.len + replacement.len) catch {
            return .{ .success = false, .output = "", .error_msg = "Allocation error during edit." };
        };
        defer new_content.deinit(alloc);

        new_content.appendSlice(alloc, file_content[0..target_idx]) catch {};
        new_content.appendSlice(alloc, replacement) catch {};
        new_content.appendSlice(alloc, file_content[target_idx + target.len ..]) catch {};

        const res = self.writeFile(path, new_content.items);
        if (res.success) {
            return .{ .success = true, .output = "File edited successfully.", .error_msg = "" };
        }
        return res;
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

    pub fn findFiles(_: NativeTools, alloc: std.mem.Allocator, pattern: []const u8, path: []const u8) ToolResult {
        var cmd_buf: [1024]u8 = undefined;
        const target = if (path.len == 0) "." else path;
        const cmd = std.fmt.bufPrint(&cmd_buf, "find \"{s}\" -name \"{s}\" | head -n 50", .{ target, pattern }) catch "find .";
        const self_tools = NativeTools{};
        return self_tools.executeCommand(alloc, cmd);
    }

    pub fn fetchWeb(_: NativeTools, alloc: std.mem.Allocator, url: []const u8) ToolResult {
        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "curl -sL --max-time 10 \"{s}\" | head -n 100", .{url}) catch return .{ .success = false, .output = "", .error_msg = "Invalid URL" };
        const self_tools = NativeTools{};
        return self_tools.executeCommand(alloc, cmd);
    }

    pub fn screenshot(_: NativeTools, alloc: std.mem.Allocator) ToolResult {
        var eye = minds_eye.MindsEye.init(alloc);
        defer eye.deinit();
        const res = eye.captureScreen();
        if (res.success) {
            const out = std.fmt.allocPrint(alloc, "Captured display snapshot: {s} ({d}x{d})", .{ res.image_path, res.width, res.height }) catch res.image_path;
            return .{ .success = true, .output = out, .error_msg = "" };
        }
        return .{ .success = false, .output = "", .error_msg = res.error_msg };
    }

    pub fn mouseClick(_: NativeTools, x: i32, y: i32) ToolResult {
        if (minds_eye.MindsEye.mouseClick(x, y)) {
            return .{ .success = true, .output = "Mouse clicked at coordinate.", .error_msg = "" };
        }
        return .{ .success = false, .output = "", .error_msg = "Failed to dispatch mouse click event." };
    }

    pub fn keyboardType(_: NativeTools, text: []const u8) ToolResult {
        if (minds_eye.MindsEye.keyboardType(text)) {
            return .{ .success = true, .output = "Keyboard text typed into target window.", .error_msg = "" };
        }
        return .{ .success = false, .output = "", .error_msg = "Failed to dispatch keystrokes." };
    }

    pub fn windowFocus(_: NativeTools, app_name: []const u8) ToolResult {
        if (minds_eye.MindsEye.windowFocus(app_name)) {
            return .{ .success = true, .output = "Focused target application window.", .error_msg = "" };
        }
        return .{ .success = false, .output = "", .error_msg = "Failed to focus target application window." };
    }

    pub fn thermodynamicQuery(_: NativeTools, alloc: std.mem.Allocator, query: []const u8) ToolResult {
        var mem = thermodynamic_memory.ThermodynamicMemory.init(alloc);
        defer mem.deinit();
        var buf: [4096]u8 = undefined;
        const len = mem.queryWorkingMemory(query, &buf);
        const out = alloc.dupe(u8, buf[0..len]) catch "";
        return .{ .success = true, .output = out, .error_msg = "" };
    }

    pub fn synthesizeNativeTool(_: NativeTools, alloc: std.mem.Allocator, name: []const u8, description: []const u8, zig_source: []const u8) ToolResult {
        var weaver = morphogenetic.MorphogeneticWeaver.init(alloc);
        defer weaver.deinit();
        return weaver.synthesizeTool(name, description, zig_source);
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
        return self.executeCommand(alloc, "git diff");
    }

    pub fn gitLog(self: NativeTools, alloc: std.mem.Allocator) ToolResult {
        return self.executeCommand(alloc, "git log -n 10 --oneline");
    }

    pub fn deterministicAnalyzeProject(self: NativeTools, alloc: std.mem.Allocator, path: []const u8) ToolResult {
        const target = if (path.len == 0) "." else path;
        
        var summary = std.ArrayList(u8).initCapacity(alloc, 2048) catch {
            return .{ .success = false, .output = "", .error_msg = "Memory error" };
        };

        const file_count_cmd = std.fmt.allocPrint(alloc, "find \"{s}\" -type f ! -path '*/.*' ! -path '*/zig-out/*' ! -path '*/.zig-cache/*' | wc -l", .{target}) catch "find . -type f | wc -l";
        defer alloc.free(file_count_cmd);
        const fcount_res = self.executeCommand(alloc, file_count_cmd);

        const loc_cmd = std.fmt.allocPrint(alloc, "find \"{s}\" -name '*.zig' -o -name '*.m' -o -name '*.h' -o -name '*.c' | xargs wc -l 2>/dev/null | tail -n 1", .{target}) catch "wc -l";
        defer alloc.free(loc_cmd);
        const loc_res = self.executeCommand(alloc, loc_cmd);

        const git_branch_res = self.executeCommand(alloc, "git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(not a git repo)'");
        const git_commit_res = self.executeCommand(alloc, "git rev-parse --short HEAD 2>/dev/null || echo 'N/A'");

        summary.appendSlice(alloc, "=== PROJECT TOPOLOGY & ARCHITECTURE REPORT ===\n") catch {};
        summary.appendSlice(alloc, "• Target Path: ") catch {};
        summary.appendSlice(alloc, target) catch {};
        summary.appendSlice(alloc, "\n• Total Tracked Files: ") catch {};
        summary.appendSlice(alloc, std.mem.trim(u8, fcount_res.output, " \t\r\n")) catch {};
        summary.appendSlice(alloc, "\n• Total Source LOC: ") catch {};
        summary.appendSlice(alloc, std.mem.trim(u8, loc_res.output, " \t\r\n")) catch {};
        summary.appendSlice(alloc, "\n• Git Branch: ") catch {};
        summary.appendSlice(alloc, std.mem.trim(u8, git_branch_res.output, " \t\r\n")) catch {};
        summary.appendSlice(alloc, " (Commit: ") catch {};
        summary.appendSlice(alloc, std.mem.trim(u8, git_commit_res.output, " \t\r\n")) catch {};
        summary.appendSlice(alloc, ")\n• Compiler: Native Zig 0.16.0 (Zero-GC Step Arena Memory Model)\n") catch {};

        return .{
            .success = true,
            .output = summary.toOwnedSlice(alloc) catch "",
            .error_msg = "",
        };
    }

    pub fn auditToolchains(self: NativeTools, alloc: std.mem.Allocator) void {
        const toolchains = [_]struct { name: []const u8, cmd: []const u8 }{
            .{ .name = "Zig Compiler", .cmd = "zig version" },
            .{ .name = "Git Version Control", .cmd = "git --version" },
            .{ .name = "cURL HTTP Client", .cmd = "curl --version | head -n 1" },
            .{ .name = "Bun JS Engine", .cmd = "bun --version" },
            .{ .name = "Python 3 Runtime", .cmd = "python3 --version" },
            .{ .name = "Rust Compiler", .cmd = "rustc --version" },
            .{ .name = "Clang / LLVM", .cmd = "clang --version | head -n 1" },
        };

        std.debug.print("\n{s}=== SYSTEM TOOLCHAIN AUDIT (/doctor) ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        for (toolchains) |t| {
            const res = self.executeCommand(alloc, t.cmd);
            const is_ok = res.success and res.output.len > 0 and std.mem.indexOf(u8, res.output, "not found") == null and std.mem.indexOf(u8, res.output, "Command completed with empty") == null;
            const badge = if (is_ok) "\x1b[38;2;49;196;141m✔ INSTALLED\x1b[0m" else "\x1b[38;2;255;107;53m✘ MISSING\x1b[0m";
            const first_line = if (std.mem.indexOfScalar(u8, res.output, '\n')) |nl| res.output[0..nl] else res.output;
            const clean_out = std.mem.trim(u8, first_line, " \t\r\n");

            std.debug.print("  • {s:<22} {s} ({s})\n", .{
                t.name,
                badge,
                if (is_ok) clean_out else "Not in PATH",
            });
        }
        std.debug.print("\n", .{});
    }

    pub fn dispatchToolJson(self: NativeTools, alloc: std.mem.Allocator, json: []const u8) ToolResult {
        if (std.mem.indexOf(u8, json, "\"read_file\"") != null) {
            const p = extractJsonField(json, "path") orelse "";
            return self.readFile(alloc, p);
        } else if (std.mem.indexOf(u8, json, "\"write_file\"") != null) {
            const p = extractJsonField(json, "path") orelse "";
            const c = extractJsonField(json, "content") orelse "";
            return self.writeFile(p, c);
        } else if (std.mem.indexOf(u8, json, "\"edit_file\"") != null) {
            const p = extractJsonField(json, "path") orelse "";
            const target = extractJsonField(json, "target") orelse "";
            const repl = extractJsonField(json, "replacement") orelse "";
            return self.editFile(alloc, p, target, repl);
        } else if (std.mem.indexOf(u8, json, "\"run_command\"") != null) {
            const cmd = extractJsonField(json, "command") orelse "";
            return self.executeCommand(alloc, cmd);
        } else if (std.mem.indexOf(u8, json, "\"list_dir\"") != null) {
            const p = extractJsonField(json, "path") orelse ".";
            return self.listDir(alloc, p);
        } else if (std.mem.indexOf(u8, json, "\"grep_search\"") != null) {
            const q = extractJsonField(json, "query") orelse "";
            const p = extractJsonField(json, "path") orelse ".";
            return self.grepSearch(alloc, q, p);
        } else if (std.mem.indexOf(u8, json, "\"find_files\"") != null) {
            const pattern = extractJsonField(json, "pattern") orelse "*";
            const p = extractJsonField(json, "path") orelse ".";
            return self.findFiles(alloc, pattern, p);
        } else if (std.mem.indexOf(u8, json, "\"fetch_web\"") != null) {
            const url = extractJsonField(json, "url") orelse "";
            return self.fetchWeb(alloc, url);
        } else if (std.mem.indexOf(u8, json, "\"screenshot\"") != null) {
            return self.screenshot(alloc);
        } else if (std.mem.indexOf(u8, json, "\"mouse_click\"") != null) {
            const x_str = extractJsonField(json, "x") orelse "100";
            const y_str = extractJsonField(json, "y") orelse "100";
            const x = std.fmt.parseInt(i32, x_str, 10) catch 100;
            const y = std.fmt.parseInt(i32, y_str, 10) catch 100;
            return self.mouseClick(x, y);
        } else if (std.mem.indexOf(u8, json, "\"keyboard_type\"") != null) {
            const text = extractJsonField(json, "text") orelse "";
            return self.keyboardType(text);
        } else if (std.mem.indexOf(u8, json, "\"window_focus\"") != null) {
            const app_name = extractJsonField(json, "app_name") orelse "";
            return self.windowFocus(app_name);
        } else if (std.mem.indexOf(u8, json, "\"thermodynamic_query\"") != null) {
            const q = extractJsonField(json, "query") orelse "";
            return self.thermodynamicQuery(alloc, q);
        } else if (std.mem.indexOf(u8, json, "\"synthesize_native_tool\"") != null) {
            const name = extractJsonField(json, "name") orelse "tool_gen";
            const desc = extractJsonField(json, "description") orelse "Synthesized native micro-tool";
            const src = extractJsonField(json, "source") orelse "pub fn main() void {}";
            return self.synthesizeNativeTool(alloc, name, desc, src);
        } else if (std.mem.indexOf(u8, json, "\"git_status\"") != null) {
            return self.gitStatus(alloc);
        } else if (std.mem.indexOf(u8, json, "\"git_diff\"") != null) {
            return self.gitDiff(alloc);
        } else if (std.mem.indexOf(u8, json, "\"git_log\"") != null) {
            return self.gitLog(alloc);
        } else if (std.mem.indexOf(u8, json, "\"git_commit\"") != null) {
            const msg = extractJsonField(json, "message") orelse "update from zigagent";
            var cmd_buf: [1024]u8 = undefined;
            const cmd = std.fmt.bufPrint(&cmd_buf, "git commit -m \"{s}\"", .{msg}) catch return .{ .success = false, .output = "", .error_msg = "Command buffer overflow" };
            return self.executeCommand(alloc, cmd);
        }

        return .{
            .success = false,
            .output = "",
            .error_msg = "Unrecognized tool format or missing tool name.",
        };
    }
};

pub fn extractJsonField(json: []const u8, field: []const u8) ?[]const u8 {
    var pat_buf: [128]u8 = undefined;
    const pat = std.fmt.bufPrint(&pat_buf, "\"{s}\":", .{field}) catch return null;

    if (std.mem.indexOf(u8, json, pat)) |idx| {
        const after_key = json[idx + pat.len ..];
        var start: usize = 0;
        while (start < after_key.len and (after_key[start] == ' ' or after_key[start] == '\t')) : (start += 1) {}

        if (start < after_key.len and after_key[start] == '"') {
            start += 1;
            var end = start;
            var escaped = false;
            while (end < after_key.len) : (end += 1) {
                if (after_key[end] == '\\') {
                    escaped = !escaped;
                } else if (after_key[end] == '"' and !escaped) {
                    return after_key[start..end];
                } else {
                    escaped = false;
                }
            }
        } else {
            // Unquoted number or boolean
            var end = start;
            while (end < after_key.len and after_key[end] != ',' and after_key[end] != '}' and after_key[end] != ' ' and after_key[end] != '\n') : (end += 1) {}
            if (end > start) {
                return after_key[start..end];
            }
        }
    }
    return null;
}
