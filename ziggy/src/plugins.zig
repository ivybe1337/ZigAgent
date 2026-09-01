const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const PluginType = enum {
    binary,
    script,
    wasm,
    extension,

    pub fn asString(self: PluginType) []const u8 {
        return switch (self) {
            .binary => "Native Executable",
            .script => "POSIX Shell/Python Script",
            .wasm => "WebAssembly Module",
            .extension => "IDE / Host Extension",
        };
    }
};

pub const PluginItem = struct {
    name: []const u8,
    version: []const u8,
    plugin_type: PluginType,
    description: []const u8,
    enabled: bool = true,
};

pub const PluginManager = struct {
    allocator: std.mem.Allocator,
    plugins: std.ArrayList(PluginItem),

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        var mgr = PluginManager{
            .allocator = allocator,
            .plugins = .empty,
        };
        mgr.discoverPlugins();
        return mgr;
    }

    pub fn deinit(self: *PluginManager) void {
        self.plugins.deinit(self.allocator);
    }

    pub fn discoverPlugins(self: *PluginManager) void {
        // Register default plugins and extension bridge
        const builtin_plugins = [_]PluginItem{
            .{ .name = "vscode-native-bridge", .version = "0.1.0", .plugin_type = .extension, .description = "Bidirectional VS Code & Cursor IPC command stream" },
            .{ .name = "posix-shell-runner", .version = "1.0.0", .plugin_type = .binary, .description = "High-speed isolated child process execution pipe" },
            .{ .name = "merkle-forest-syncer", .version = "0.2.0", .plugin_type = .binary, .description = "Content-addressed SHA-256 state serialization engine" },
            .{ .name = "omnilattice-mesh-gateway", .version = "1.1.0", .plugin_type = .binary, .description = "Global inter-agent causal DAG distribution channel" },
        };

        for (builtin_plugins) |p| {
            self.plugins.append(self.allocator, p) catch {};
        }
    }

    pub fn listPlugins(self: *const PluginManager) void {
        std.debug.print("\n{s}=== INSTALLED PLUGINS & EXTENSIONS ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        for (self.plugins.items) |p| {
            const status = if (p.enabled) "\x1b[38;2;49;196;141m✔ ENABLED\x1b[0m" else "\x1b[38;2;255;107;53m✘ DISABLED\x1b[0m";
            std.debug.print("  • {s} \x1b[1;38;2;255;107;53m{s:<26}\x1b[0m v{s} ({s})\n", .{
                status, p.name, p.version, p.plugin_type.asString(),
            });
            std.debug.print("    \x1b[38;2;139;157;175m{s}\x1b[0m\n", .{p.description});
        }
        std.debug.print("\n{s}Plugins dynamically extend Ziggy's native toolchain and cognitive capabilities.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }
};
