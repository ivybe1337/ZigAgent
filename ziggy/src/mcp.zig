const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const McpToolParam = struct {
    name: []const u8,
    param_type: []const u8,
    description: []const u8,
    required: bool,
};

pub const McpTool = struct {
    server_name: []const u8,
    name: []const u8,
    description: []const u8,
    command: []const u8,
};

pub const McpServerConfig = struct {
    name: []const u8,
    command: []const u8,
    args: []const []const u8,
    env: []const []const u8,
    is_active: bool = true,
};

pub const McpManager = struct {
    allocator: std.mem.Allocator,
    storage_dir: []const u8,
    tools: std.ArrayList(McpTool),

    pub fn init(allocator: std.mem.Allocator, storage_dir: []const u8) McpManager {
        var mgr = McpManager{
            .allocator = allocator,
            .storage_dir = storage_dir,
            .tools = .empty,
        };
        mgr.discoverLocalServers();
        return mgr;
    }

    pub fn deinit(self: *McpManager) void {
        self.tools.deinit(self.allocator);
    }

    pub fn discoverLocalServers(self: *McpManager) void {
        // Scan ~/.ziggy/mcp.json or default registered MCP servers
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        var config_path_buf: [512]u8 = undefined;
        const config_path = std.fmt.bufPrint(&config_path_buf, "{s}/.ziggy/mcp.json", .{home[0..home_len]}) catch return;

        const content = sys.readEntireFile(self.allocator, config_path, 8192);
        if (content) |json_str| {
            defer self.allocator.free(json_str);
            var lines = std.mem.splitScalar(u8, json_str, '\n');
            while (lines.next()) |line| {
                const tr = std.mem.trim(u8, line, " \t\r,");
                if (std.mem.indexOf(u8, tr, "\"command\":") != null) {
                    // Register dynamic server entry if configured
                }
            }
        }

        // Register default OmniLattice tools
        self.tools.append(self.allocator, .{
            .server_name = "omnilattice",
            .name = "omnilattice_forest_get",
            .description = "Retrieve Merkle Forest state from OmniLattice mesh",
            .command = "omnilattice-mcp",
        }) catch {};

        self.tools.append(self.allocator, .{
            .server_name = "omnilattice",
            .name = "omnilattice_message_send",
            .description = "Send cross-agent message to another active project node",
            .command = "omnilattice-mcp",
        }) catch {};
    }

    pub fn callMcpTool(self: *McpManager, server: []const u8, tool: []const u8, args_json: []const u8, out_buf: []u8) usize {
        _ = self;
        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "printf '{{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{{\"name\":\"{s}\",\"arguments\":{s}}}}}\\\\n' | {s} 2>/dev/null",
            .{ tool, args_json, server },
        ) catch return 0;

        cmd_buf[cmd.len] = 0;
        const cmd_z: [*:0]const u8 = @ptrCast(cmd_buf[0..cmd.len]);
        const pipe = sys.Sys.popen(cmd_z, "r") orelse {
            const err_msg = "Error: MCP server could not be spawned.";
            const len = @min(err_msg.len, out_buf.len);
            @memcpy(out_buf[0..len], err_msg[0..len]);
            return len;
        };
        defer _ = sys.Sys.pclose(pipe);

        var total_read: usize = 0;
        while (total_read < out_buf.len - 1) {
            const dest_ptr: [*]u8 = @ptrCast(&out_buf[total_read]);
            const r = sys.Sys.fread(dest_ptr, 1, out_buf.len - 1 - total_read, pipe);
            if (r <= 0) break;
            total_read += r;
        }

        if (total_read == 0) {
            const err_msg = "Error: MCP tool returned empty response or server exited.";
            const len = @min(err_msg.len, out_buf.len);
            @memcpy(out_buf[0..len], err_msg[0..len]);
            return len;
        }

        out_buf[total_read] = 0;
        return total_read;
    }

    pub fn listMcpTools(self: *const McpManager) void {
        std.debug.print("\n{s}=== CONNECTED MCP SERVERS & TOOLS (Model Context Protocol) ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        if (self.tools.items.len == 0) {
            std.debug.print("  {s}• No active MCP servers configured. Add servers to ~/.ziggy/mcp.json{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
            return;
        }

        for (self.tools.items) |t| {
            std.debug.print("  • {s}[{s}]{s} \x1b[1m{s}\x1b[0m: {s}\n", .{
                tui.TUI.C_AQUA, t.server_name, tui.TUI.C_RESET,
                t.name, t.description,
            });
        }
        std.debug.print("\n{s}Use /mcp call <server> <tool> <json_args> or let Ziggy invoke tools automatically.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }
};
