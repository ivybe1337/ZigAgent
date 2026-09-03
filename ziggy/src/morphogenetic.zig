const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const tools = @import("tools.zig");

pub const MorphicTool = struct {
    name: []const u8,
    binary_path: []const u8,
    description: []const u8,
    compiled_at: i64,
};

pub const MorphogeneticWeaver = struct {
    allocator: std.mem.Allocator,
    tools_dir: []const u8,
    registered_tools: std.ArrayList(MorphicTool),

    pub fn init(allocator: std.mem.Allocator) MorphogeneticWeaver {
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        const dir = std.fmt.allocPrint(allocator, "{s}/.ziggy/morphogenetic_tools", .{home[0..home_len]}) catch ".";
        _ = sys.makeDirAll(dir);

        return .{
            .allocator = allocator,
            .tools_dir = dir,
            .registered_tools = .empty,
        };
    }

    pub fn deinit(self: *MorphogeneticWeaver) void {
        for (self.registered_tools.items) |t| {
            self.allocator.free(t.name);
            self.allocator.free(t.binary_path);
            self.allocator.free(t.description);
        }
        self.registered_tools.deinit(self.allocator);
        self.allocator.free(self.tools_dir);
    }

    /// Autonomously compile and link a newly synthesized Zig micro-tool
    pub fn synthesizeTool(
        self: *MorphogeneticWeaver,
        name: []const u8,
        description: []const u8,
        zig_source: []const u8,
    ) tools.ToolResult {
        // 1. Write source file
        var src_path_buf: [512]u8 = undefined;
        const src_path = std.fmt.bufPrint(&src_path_buf, "{s}/{s}.zig", .{ self.tools_dir, name }) catch {
            return .{ .success = false, .output = "", .error_msg = "Buffer overflow for tool source path" };
        };

        if (!sys.writeEntireFile(src_path, zig_source)) {
            return .{ .success = false, .output = "", .error_msg = "Failed to write synthesized tool source code" };
        }

        // 2. Compile to standalone Mach-O release binary
        var bin_path_buf: [512]u8 = undefined;
        const bin_path = std.fmt.bufPrint(&bin_path_buf, "{s}/{s}", .{ self.tools_dir, name }) catch {
            return .{ .success = false, .output = "", .error_msg = "Buffer overflow for binary output path" };
        };

        var compile_cmd_buf: [1024]u8 = undefined;
        const compile_cmd = std.fmt.bufPrint(
            &compile_cmd_buf,
            "zig build-exe -OReleaseFast \"{s}\" -femit-bin=\"{s}\" 2>&1",
            .{ src_path, bin_path },
        ) catch {
            return .{ .success = false, .output = "", .error_msg = "Buffer overflow for compile command" };
        };

        const native_tools = tools.NativeTools{};
        const compile_res = native_tools.executeCommand(self.allocator, compile_cmd);

        if (!compile_res.success or std.mem.indexOf(u8, compile_res.output, "error:") != null) {
            return .{
                .success = false,
                .output = compile_res.output,
                .error_msg = "Compilation of morphogenetic tool failed. See compiler output.",
            };
        }

        // 3. Register compiled tool
        const dup_name = self.allocator.dupe(u8, name) catch return .{ .success = false, .output = "", .error_msg = "OOM" };
        const dup_bin = self.allocator.dupe(u8, bin_path) catch return .{ .success = false, .output = "", .error_msg = "OOM" };
        const dup_desc = self.allocator.dupe(u8, description) catch return .{ .success = false, .output = "", .error_msg = "OOM" };

        self.registered_tools.append(self.allocator, .{
            .name = dup_name,
            .binary_path = dup_bin,
            .description = dup_desc,
            .compiled_at = sys.currentTimestamp(),
        }) catch {};

        var success_buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &success_buf,
            "✔ Morphogenetic synthesis successful: Compiled native binary at {s}. Tool registered in active dispatch table.",
            .{bin_path},
        ) catch "Morphogenetic tool compiled successfully.";

        return .{
            .success = true,
            .output = self.allocator.dupe(u8, msg) catch msg,
            .error_msg = "",
        };
    }

    /// Execute a synthesized morphogenetic tool
    pub fn executeSynthesizedTool(self: *MorphogeneticWeaver, name: []const u8, args: []const u8) tools.ToolResult {
        for (self.registered_tools.items) |t| {
            if (std.mem.eql(u8, t.name, name)) {
                var cmd_buf: [2048]u8 = undefined;
                const cmd = std.fmt.bufPrint(&cmd_buf, "\"{s}\" {s}", .{ t.binary_path, args }) catch {
                    return .{ .success = false, .output = "", .error_msg = "Command buffer overflow" };
                };
                const native_tools = tools.NativeTools{};
                return native_tools.executeCommand(self.allocator, cmd);
            }
        }

        return .{
            .success = false,
            .output = "",
            .error_msg = "Synthesized tool not found in morphogenetic registry",
        };
    }

    pub fn listSynthesizedTools(self: *const MorphogeneticWeaver) void {
        std.debug.print("\n{s}=== MORPHOGENETIC NATIVE COMPILED TOOLS ({d} Active) ==={s}\n", .{ tui.TUI.C_CYAN, self.registered_tools.items.len, tui.TUI.C_RESET });
        if (self.registered_tools.items.len == 0) {
            std.debug.print("  • No dynamic micro-tools synthesized yet. Use `synthesize_native_tool` to weave new binaries.\n\n", .{});
            return;
        }

        for (self.registered_tools.items) |t| {
            std.debug.print("  • \x1b[1;38;2;255;107;53m{s:<24}\x1b[0m : {s}\n    \x1b[38;2;139;157;175mBinary: {s}\x1b[0m\n", .{
                t.name, t.description, t.binary_path,
            });
        }
        std.debug.print("\n", .{});
    }
};
