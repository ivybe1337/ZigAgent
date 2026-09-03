const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const config = @import("config.zig");

pub const SlashItem = struct {
    cmd: []const u8,
    desc: []const u8,
};

pub const AVAILABLE_COMMANDS = [_]SlashItem{
    .{ .cmd = "/settings", .desc = "Interactive settings & preferences panel" },
    .{ .cmd = "/deliberate", .desc = "Run 4-pass recursive metacognitive deliberation" },
    .{ .cmd = "/swarm", .desc = "Execute 4-agent parallel swarm orchestration" },
    .{ .cmd = "/query", .desc = "Structural AST symbol query across codebase" },
    .{ .cmd = "/evolve", .desc = "Run autonomous self-analysis & code evolution" },
    .{ .cmd = "/msg", .desc = "Send message via iMessage, Telegram, or WhatsApp" },
    .{ .cmd = "/listen", .desc = "Start live inbound messaging listener daemon" },
    .{ .cmd = "/bridges", .desc = "Inspect multi-platform messaging gateways" },
    .{ .cmd = "/remote", .desc = "Launch Manus-style cloud desktop gateway" },
    .{ .cmd = "/serve", .desc = "Start background HTTP & WebSocket remote server" },
    .{ .cmd = "/commands", .desc = "Explore categorized commands & subcategories" },
    .{ .cmd = "/terminal", .desc = "Terminal & shell command runner (!<cmd>)" },
    .{ .cmd = "/mcp", .desc = "Model Context Protocol (MCP) servers & tools" },
    .{ .cmd = "/skills", .desc = "List loaded skills & domain playbooks" },
    .{ .cmd = "/skill", .desc = "Activate a specialized skill playbook" },
    .{ .cmd = "/plugins", .desc = "Manage dynamic plugins & extensions" },
    .{ .cmd = "/omni", .desc = "OmniLattice context mesh & semantic forest" },
    .{ .cmd = "/unbounded", .desc = "Toggle unbounded infinite autonomy mode" },
    .{ .cmd = "/models", .desc = "Browse all frontier & stealth models" },
    .{ .cmd = "/model", .desc = "Switch active inference model" },
    .{ .cmd = "/compact", .desc = "Targeted context compaction" },
    .{ .cmd = "/speculate", .desc = "Multi-candidate speculative plan evaluator" },
    .{ .cmd = "/council", .desc = "3-Lens consensus evaluation (Security/Perf/Arch)" },
    .{ .cmd = "/ast", .desc = "Verify structural balanced delimiter integrity" },
    .{ .cmd = "/snapshot", .desc = "Create point-in-time state checkpoint" },
    .{ .cmd = "/rollback", .desc = "Revert workspace to previous state snapshot" },
    .{ .cmd = "/timeline", .desc = "Inspect state snapshots in Time Machine" },
    .{ .cmd = "/ledger", .desc = "Cross-agent continuity ledger" },
    .{ .cmd = "/inbox", .desc = "Inter-agent mailbox inbox" },
    .{ .cmd = "/keys", .desc = "AI provider credential status" },
    .{ .cmd = "/doctor", .desc = "Check system toolchains & health" },
    .{ .cmd = "/clear", .desc = "Clear terminal screen" },
    .{ .cmd = "/exit", .desc = "Exit ZigAgent CLI" },
};

pub const InteractiveTUI = struct {
    /// Safe, robust terminal input reader with ZERO password / raw mode interference
    pub fn readInputWithAutocomplete(
        allocator: std.mem.Allocator,
        prompt_prefix: []const u8,
        out_buf: []u8,
        history: *std.ArrayList([]const u8),
    ) ?[]const u8 {
        _ = sys.Sys.write(1, prompt_prefix.ptr, prompt_prefix.len);

        var buf: [4096]u8 = undefined;
        var total_read: usize = 0;
        while (total_read < buf.len - 1) {
            var ch: [1]u8 = undefined;
            const r = sys.Sys.read(0, &ch, 1);
            if (r <= 0) {
                if (total_read == 0) return null;
                break;
            }
            if (ch[0] == '\n' or ch[0] == '\r') {
                break;
            }
            buf[total_read] = ch[0];
            total_read += 1;
        }
        buf[total_read] = 0;

        const raw_slice = buf[0..total_read];
        const trimmed = std.mem.trim(u8, raw_slice, " \t\r\n");
        if (trimmed.len > 0) {
            const dup = allocator.dupe(u8, trimmed) catch "";
            if (dup.len > 0) history.append(allocator, dup) catch {};
        }

        const out_len = @min(trimmed.len, out_buf.len);
        @memcpy(out_buf[0..out_len], trimmed[0..out_len]);
        return out_buf[0..out_len];
    }

    /// Robust, interactive Settings Menu with instant single-key toggles
    pub fn runInteractiveSettings(cfg_mgr: *config.ConfigManager) void {
        var term_orig: sys.Termios = undefined;
        const has_tty = (sys.Sys.tcgetattr(0, &term_orig) == 0);
        if (has_tty) {
            var term_raw = term_orig;
            term_raw.c_lflag &= ~(sys.DARWIN_ICANON | sys.DARWIN_ECHO | sys.DARWIN_IEXTEN);
            term_raw.c_cc[sys.VMIN] = 1;
            term_raw.c_cc[sys.VTIME] = 0;
            _ = sys.Sys.tcsetattr(0, sys.TCSANOW, &term_raw);
        }
        defer if (has_tty) {
            _ = sys.Sys.tcsetattr(0, sys.TCSANOW, &term_orig);
        };

        while (true) {
            renderSettingsScreen(cfg_mgr);

            const prompt_str = "\x1b[38;2;60;80;110m│ \x1b[1;38;2;0;242;254mType [1-8] to toggle • [ENTER/q/ESC to return]\x1b[0m ❯ ";
            _ = sys.Sys.write(1, prompt_str, prompt_str.len);

            var ch: [8]u8 = undefined;
            const r = sys.Sys.read(0, @ptrCast(&ch), 8);
            if (r <= 0) break;

            if (ch[0] == 'q' or ch[0] == 'Q' or ch[0] == '\n' or ch[0] == '\r' or ch[0] == 27) {
                break;
            }

            if (ch[0] >= '1' and ch[0] <= '8') {
                const idx: usize = @intCast(ch[0] - '1');
                toggleSetting(cfg_mgr, idx);
            }
        }

        std.debug.print("\n\x1b[2J\x1b[H{s}✔ Configuration saved to {s}{s}\n\n", .{ tui.TUI.C_AQUA, cfg_mgr.config_path[0..cfg_mgr.config_path_len], tui.TUI.C_RESET });
    }

    fn toggleSetting(cfg: *config.ConfigManager, idx: usize) void {
        switch (idx) {
            0 => {
                const next_v: config.VerbosityMode = switch (cfg.config.verbosity) {
                    .quiet => .normal,
                    .normal => .full_transcript,
                    .full_transcript => .quiet,
                };
                cfg.config.verbosity = next_v;
            },
            1 => {
                const next_r: config.ThinkingEffort = switch (cfg.config.thinking_effort) {
                    .low => .medium,
                    .medium => .high,
                    .high => .max,
                    .max => .low,
                };
                cfg.config.thinking_effort = next_r;
            },
            2 => cfg.config.unbounded_autonomy = !cfg.config.unbounded_autonomy,
            3 => cfg.config.stream_output = !cfg.config.stream_output,
            4 => cfg.config.sandbox_enabled = !cfg.config.sandbox_enabled,
            5 => {
                const next_c: config.ContextStrategy = switch (cfg.config.context_strategy) {
                    .hierarchical_engrams => .rolling_window,
                    .rolling_window => .full_replay,
                    .full_replay => .hierarchical_engrams,
                };
                cfg.config.context_strategy = next_c;
            },
            6 => cfg.config.pre_compact_dump = !cfg.config.pre_compact_dump,
            7 => {
                cfg.config.auto_compact_threshold_pct = if (cfg.config.auto_compact_threshold_pct >= 90)
                    70
                else
                    cfg.config.auto_compact_threshold_pct + 10;
            },
            else => {},
        }
        cfg.save();
    }

    fn renderSettingsScreen(cfg_mgr: *config.ConfigManager) void {
        var thresh_buf: [32]u8 = undefined;
        const thresh_str = std.fmt.bufPrint(&thresh_buf, "{d}% context limit", .{cfg_mgr.config.auto_compact_threshold_pct}) catch "80%";

        const items = [_]struct { label: []const u8, val: []const u8 }{
            .{ .label = "1. Verbosity Mode", .val = cfg_mgr.config.verbosity.asString() },
            .{ .label = "2. Thinking Effort", .val = cfg_mgr.config.thinking_effort.asString() },
            .{ .label = "3. Unbounded Autonomy", .val = if (cfg_mgr.config.unbounded_autonomy) "ENABLED (Infinite Steps)" else "DISABLED (Step-Limited)" },
            .{ .label = "4. Real-Time Streaming", .val = if (cfg_mgr.config.stream_output) "ENABLED (Live SSE)" else "DISABLED" },
            .{ .label = "5. Security Sandbox", .val = if (cfg_mgr.config.sandbox_enabled) "ACTIVE (Strict Non-Destructive)" else "PERMISSIVE" },
            .{ .label = "6. Context Strategy", .val = cfg_mgr.config.context_strategy.asString() },
            .{ .label = "7. Pre-Compaction Dump", .val = if (cfg_mgr.config.pre_compact_dump) "ENABLED (Auto-save)" else "DISABLED" },
            .{ .label = "8. Auto-Compact Threshold", .val = thresh_str },
        };

        std.debug.print(
            \\
            \\{s}╭─────────────────────────────────────────────────────────────────────────────╮{s}
            \\{s}│                    ⚡ ZIGAGENT SETTINGS & PREFERENCES                        │{s}
            \\{s}├─────────────────────────────────────────────────────────────────────────────┤{s}
            \\{s}│  Type number [1-8] and press ENTER to toggle • Press ENTER/q to return      │{s}
            \\{s}├─────────────────────────────────────────────────────────────────────────────┤{s}
            \\
        , .{
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
            tui.TUI.C_CYAN, tui.TUI.C_RESET,
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
            tui.TUI.C_MUTED, tui.TUI.C_RESET,
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
        });

        for (items, 0..) |item, idx| {
            _ = idx;
            std.debug.print(
                "{s}│{s}  \x1b[1;38;2;0;242;254m{s:<26}\x1b[0m : \x1b[1;38;2;49;196;141m{s:<40}\x1b[0m{s}│{s}\n",
                .{ tui.TUI.C_BORDER, tui.TUI.C_RESET, item.label, item.val, tui.TUI.C_BORDER, tui.TUI.C_RESET },
            );
        }

        std.debug.print(
            \\{s}╰─────────────────────────────────────────────────────────────────────────────╯{s}
            \\{s}  Config File: {s}{s}
            \\
        , .{ tui.TUI.C_BORDER, tui.TUI.C_RESET, tui.TUI.C_MUTED, cfg_mgr.config_path[0..cfg_mgr.config_path_len], tui.TUI.C_RESET });
    }
};
