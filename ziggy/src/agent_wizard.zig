const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const AgentProfile = struct {
    name: []const u8,
    description: []const u8,
    system_prompt: []const u8,
    allowed_tools: []const u8,
    model_override: ?[]const u8 = null,
};

pub const AgentWizard = struct {
    pub fn createAgent(
        allocator: std.mem.Allocator,
        name: []const u8,
        description: []const u8,
        system_prompt: []const u8,
        tools: []const u8,
    ) bool {
        var home_path: [256]u8 = undefined;
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        @memcpy(home_path[0..home_len], home[0..home_len]);

        var dir_buf: [512]u8 = undefined;
        const dir = std.fmt.bufPrint(&dir_buf, "{s}/.ziggy/agents", .{home_path[0..home_len]}) catch return false;
        _ = sys.makeDirAll(dir);

        var file_buf: [512]u8 = undefined;
        const file_path = std.fmt.bufPrint(&file_buf, "{s}/{s}.json", .{ dir, name }) catch return false;

        var json_buf: [4096]u8 = undefined;
        const json = std.fmt.bufPrint(
            &json_buf,
            \\{{
            \\  "name": "{s}",
            \\  "description": "{s}",
            \\  "system_prompt": "{s}",
            \\  "allowed_tools": "{s}",
            \\  "created_at": {d}
            \\}}
            \\
        , .{ name, description, system_prompt, tools, sys.currentTimestamp() }) catch return false;

        _ = allocator;
        return sys.writeEntireFile(file_path, json);
    }

    pub fn listAgents(allocator: std.mem.Allocator) void {
        var home_path: [256]u8 = undefined;
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        @memcpy(home_path[0..home_len], home[0..home_len]);

        var dir_buf: [512]u8 = undefined;
        const dir = std.fmt.bufPrint(&dir_buf, "{s}/.ziggy/agents", .{home_path[0..home_len]}) catch return;
        _ = sys.makeDirAll(dir);

        std.debug.print(
            \\
            \\{s}=== SPECIALIZED CUSTOM AGENTS REGISTRY ==={s}
            \\  • default                      [Core Autonomous Agent]
            \\  • code-architect               [Specialized Zero-Leak Zig & Systems Engineer]
            \\  • security-auditor             [Static AST Invariant & Boundary Verification]
            \\─────────────────────────────────────────────────────────────────────────────
            \\{s}Use {s}/agent switch <name>{s} or create a new agent with {s}/create-agent <name> <description>{s}
            \\
        , .{ tui.TUI.C_CYAN, tui.TUI.C_RESET, tui.TUI.C_MUTED, tui.TUI.C_ORANGE, tui.TUI.C_MUTED, tui.TUI.C_AQUA, tui.TUI.C_RESET });
        _ = allocator;
    }
};
