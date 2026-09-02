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
    /// Dedicated graphical chatbox reader
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
        const trimmed = std.mem.trim(u8, raw_slice, "\r\n");
        if (trimmed.len > 0) {
            const dup = allocator.dupe(u8, trimmed) catch "";
            if (dup.len > 0) history.append(allocator, dup) catch {};
        }

        const out_len = @min(trimmed.len, out_buf.len);
        @memcpy(out_buf[0..out_len], trimmed[0..out_len]);
        return out_buf[0..out_len];
    }

    /// Interactive TUI Settings View with Arrow Keys, j/k, and Spacebar Toggling
    pub fn runInteractiveSettings(cfg_mgr: *config.ConfigManager) void {
        var term_raw: sys.Termios = undefined;
        var term_orig: sys.Termios = undefined;
        if (sys.Sys.tcgetattr(0, &term_orig) != 0) return;
        term_raw = term_orig;
        // Non-canonical, turn off echoing
        term_raw.c_lflag &= ~@as(c_ulong, 0x00000002 | 0x00000008);
        term_raw.c_cc[16] = 1; // VMIN = 1
        term_raw.c_cc[17] = 0; // VTIME = 0
        _ = sys.Sys.tcsetattr(0, 0, &term_raw);
        defer _ = sys.Sys.tcsetattr(0, 0, &term_orig);

        var selected: usize = 0;
        const total_items: usize = 8;

        while (true) {
            renderSettingsScreen(cfg_mgr, selected);

            var ch: [8]u8 = undefined;
            const r = sys.Sys.read(0, @ptrCast(&ch), 8);
            if (r <= 0) break;

            // Handle ESC alone or 'q'
            if (r == 1 and (ch[0] == 'q' or ch[0] == 'Q' or ch[0] == 27 or ch[0] == 'x' or ch[0] == 'X')) {
                break;
            }

            // Arrow Up (CSI [ A or SS3 O A or 'k')
            if ((r >= 3 and ch[0] == 27 and (ch[1] == '[' or ch[1] == 'O') and ch[2] == 'A') or ch[0] == 'k' or ch[0] == 'K') {
                if (selected > 0) selected -= 1 else selected = total_items - 1;
                continue;
            }

            // Arrow Down (CSI [ B or SS3 O B or 'j')
            if ((r >= 3 and ch[0] == 27 and (ch[1] == '[' or ch[1] == 'O') and ch[2] == 'B') or ch[0] == 'j' or ch[0] == 'J') {
                if (selected < total_items - 1) selected += 1 else selected = 0;
                continue;
            }

            // Space, Enter, or Right Arrow to Toggle
            if (ch[0] == ' ' or ch[0] == '\n' or ch[0] == '\r' or (r >= 3 and ch[0] == 27 and ch[2] == 'C')) {
                toggleSetting(cfg_mgr, selected);
                continue;
            }
        }

        _ = sys.Sys.write(1, "\x1b[2J\x1b[H", 7);
        std.debug.print("{s}✔ Configuration saved to {s}{s}\n\n", .{ tui.TUI.C_AQUA, cfg_mgr.config_path[0..cfg_mgr.config_path_len], tui.TUI.C_RESET });
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

    fn renderSettingsScreen(cfg_mgr: *config.ConfigManager, selected: usize) void {
        var buf: [4096]u8 = undefined;
        var cursor: usize = 0;

        const hdr = std.fmt.bufPrint(
            buf[cursor..],
            \\{s}
            \\{s}╭─────────────────────────────────────────────────────────────────────────────╮{s}
            \\{s}│                    ⚡ ZIGAGENT INTERACTIVE SETTINGS PANEL                   │{s}
            \\{s}├─────────────────────────────────────────────────────────────────────────────┤{s}
            \\{s}│  [↑/↓] Navigate  •  [SPACE/ENTER] Toggle / Cycle  •  [q/ESC] Save & Exit     │{s}
            \\{s}╰─────────────────────────────────────────────────────────────────────────────╯{s}
            \\
        , .{
            "\x1b[2J\x1b[H",
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
            tui.TUI.C_CYAN, tui.TUI.C_RESET,
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
            tui.TUI.C_MUTED, tui.TUI.C_RESET,
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
        }) catch return;
        cursor += hdr.len;

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

        for (items, 0..) |item, idx| {
            const is_sel = (idx == selected);
            const prefix = if (is_sel) "  \x1b[48;2;25;40;60m\x1b[38;2;83;182;255m ▶ " else "     ";
            const reset = "\x1b[0m";
            const val_color = if (is_sel) "\x1b[1;38;2;49;196;141m" else "\x1b[38;2;240;246;252m";

            const row = std.fmt.bufPrint(
                buf[cursor..],
                "{s}{s:<28} : {s}{s:<38}{s}\n",
                .{ prefix, item.label, val_color, item.val, reset },
            ) catch break;
            cursor += row.len;
        }

        const footer = std.fmt.bufPrint(
            buf[cursor..],
            \\
            \\{s}─────────────────────────────────────────────────────────────────────────────{s}
            \\{s}  Config File: {s}{s}
            \\
        , .{ tui.TUI.C_BORDER, tui.TUI.C_RESET, tui.TUI.C_MUTED, cfg_mgr.config_path[0..cfg_mgr.config_path_len], tui.TUI.C_RESET }) catch return;
        cursor += footer.len;

        _ = sys.Sys.write(1, @ptrCast(&buf), cursor);
    }
};
