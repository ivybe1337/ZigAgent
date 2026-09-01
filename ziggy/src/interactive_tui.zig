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
    .{ .cmd = "/commands", .desc = "Explore categorized commands & subcategories" },
    .{ .cmd = "/terminal", .desc = "Terminal & shell command runner (!<cmd>)" },
    .{ .cmd = "/omni", .desc = "OmniLattice context mesh & semantic forest" },
    .{ .cmd = "/unbounded", .desc = "Toggle unbounded infinite autonomy mode" },
    .{ .cmd = "/models", .desc = "Browse all frontier & stealth models" },
    .{ .cmd = "/model", .desc = "Switch active inference model" },
    .{ .cmd = "/compact", .desc = "Targeted context compaction" },
    .{ .cmd = "/agents", .desc = "List specialized custom agents" },
    .{ .cmd = "/create-agent", .desc = "Create specialized agent profile" },
    .{ .cmd = "/speculate", .desc = "Run multi-branch speculative execution" },
    .{ .cmd = "/provenance", .desc = "View causal DAG trace graph" },
    .{ .cmd = "/council", .desc = "Run 3-perspective consensus review" },
    .{ .cmd = "/ast", .desc = "AST structural integrity guard" },
    .{ .cmd = "/invariants", .desc = "Verify formal invariant gates" },
    .{ .cmd = "/snapshot", .desc = "Create Time Machine state snapshot" },
    .{ .cmd = "/timeline", .desc = "List historical recovery checkpoints" },
    .{ .cmd = "/ledger", .desc = "Cross-agent continuity ledger" },
    .{ .cmd = "/inbox", .desc = "Inter-agent mailbox inbox" },
    .{ .cmd = "/keys", .desc = "AI provider credential status" },
    .{ .cmd = "/doctor", .desc = "Check system toolchains & health" },
    .{ .cmd = "/clear", .desc = "Clear terminal screen" },
    .{ .cmd = "/exit", .desc = "Exit ZigAgent CLI" },
};

pub const InteractiveTUI = struct {
    pub fn readInputWithAutocomplete(
        allocator: std.mem.Allocator,
        prompt_prefix: []const u8,
        out_buf: []u8,
        history: *std.ArrayList([]const u8),
    ) ?[]const u8 {
        var raw_term: sys.Termios = undefined;
        var orig_term: sys.Termios = undefined;
        if (sys.Sys.tcgetattr(0, &orig_term) != 0) {
            return fallbackReadLine(out_buf);
        }
        raw_term = orig_term;
        raw_term.c_lflag &= ~@as(c_ulong, 0x00000002 | 0x00000008); // ~ICANON, ~ECHO
        raw_term.c_cc[16] = 1; // VMIN = 1
        raw_term.c_cc[17] = 0; // VTIME = 0
        _ = sys.Sys.tcsetattr(0, 0, &raw_term);

        defer _ = sys.Sys.tcsetattr(0, 0, &orig_term);

        var line_buf: [4096]u8 = undefined;
        var len: usize = 0;
        var cursor_pos: usize = 0;
        var selected_idx: usize = 0;
        var history_idx: ?usize = null;

        renderLine(prompt_prefix, line_buf[0..len], cursor_pos, null, 0);

        while (true) {
            var ch: [4]u8 = undefined;
            const r = sys.Sys.read(0, @ptrCast(&ch), 4);
            if (r <= 0) return null;

            // Handle Key Escapes / Arrow Keys
            if (ch[0] == 27) {
                if (r == 1) {
                    // Plain ESC key
                    if (len > 0 and line_buf[0] == '/') {
                        // Close autocomplete menu
                        selected_idx = 0;
                        renderLine(prompt_prefix, line_buf[0..len], cursor_pos, null, 0);
                        continue;
                    }
                    return null;
                }
                if (ch[1] == '[') {
                    if (ch[2] == 'A') { // UP ARROW
                        if (len > 0 and line_buf[0] == '/') {
                            if (selected_idx > 0) selected_idx -= 1;
                        } else if (history.items.len > 0) {
                            const new_h = if (history_idx) |hi| (if (hi > 0) hi - 1 else 0) else history.items.len - 1;
                            history_idx = new_h;
                            const h_str = history.items[new_h];
                            len = @min(h_str.len, line_buf.len);
                            @memcpy(line_buf[0..len], h_str[0..len]);
                            cursor_pos = len;
                        }
                    } else if (ch[2] == 'B') { // DOWN ARROW
                        if (len > 0 and line_buf[0] == '/') {
                            selected_idx += 1;
                        } else if (history_idx != null) {
                            const new_h = history_idx.? + 1;
                            if (new_h < history.items.len) {
                                history_idx = new_h;
                                const h_str = history.items[new_h];
                                len = @min(h_str.len, line_buf.len);
                                @memcpy(line_buf[0..len], h_str[0..len]);
                                cursor_pos = len;
                            } else {
                                history_idx = null;
                                len = 0;
                                cursor_pos = 0;
                            }
                        }
                    } else if (ch[2] == 'C') { // RIGHT ARROW
                        if (cursor_pos < len) cursor_pos += 1;
                    } else if (ch[2] == 'D') { // LEFT ARROW
                        if (cursor_pos > 0) cursor_pos -= 1;
                    }
                    renderMenuOrLine(prompt_prefix, line_buf[0..len], cursor_pos, &selected_idx);
                    continue;
                }
            }

            // Enter key
            if (ch[0] == '\n' or ch[0] == '\r') {
                if (len > 0 and line_buf[0] == '/' and !std.mem.containsAtLeast(u8, line_buf[0..len], 1, " ")) {
                    // Autocomplete selected command
                    const matched = filterCommands(line_buf[0..len]);
                    if (matched.len > 0) {
                        const sel = @min(selected_idx, matched.len - 1);
                        const sel_cmd = matched[sel].cmd;
                        len = @min(sel_cmd.len, line_buf.len);
                        @memcpy(line_buf[0..len], sel_cmd[0..len]);
                        cursor_pos = len;
                    }
                }
                // Clear dropdown and print newline
                _ = sys.Sys.write(1, "\x1b[J\n", 4);

                const final_str = line_buf[0..len];
                if (final_str.len > 0) {
                    const dup = allocator.dupe(u8, final_str) catch "";
                    if (dup.len > 0) history.append(allocator, dup) catch {};
                }
                const out_len = @min(final_str.len, out_buf.len);
                @memcpy(out_buf[0..out_len], final_str[0..out_len]);
                return out_buf[0..out_len];
            }

            // Tab key (Auto-complete)
            if (ch[0] == '\t') {
                if (len > 0 and line_buf[0] == '/') {
                    const matched = filterCommands(line_buf[0..len]);
                    if (matched.len > 0) {
                        const sel = @min(selected_idx, matched.len - 1);
                        const sel_cmd = matched[sel].cmd;
                        len = @min(sel_cmd.len, line_buf.len);
                        @memcpy(line_buf[0..len], sel_cmd[0..len]);
                        cursor_pos = len;
                    }
                }
                renderMenuOrLine(prompt_prefix, line_buf[0..len], cursor_pos, &selected_idx);
                continue;
            }

            // Backspace / Delete
            if (ch[0] == 127 or ch[0] == 8) {
                if (cursor_pos > 0) {
                    if (cursor_pos < len) {
                        var i: usize = cursor_pos - 1;
                        while (i < len - 1) : (i += 1) {
                            line_buf[i] = line_buf[i + 1];
                        }
                    }
                    len -= 1;
                    cursor_pos -= 1;
                    selected_idx = 0;
                }
                renderMenuOrLine(prompt_prefix, line_buf[0..len], cursor_pos, &selected_idx);
                continue;
            }

            // Normal printable character
            if (ch[0] >= 32 and ch[0] <= 126 and len < line_buf.len - 1) {
                if (cursor_pos < len) {
                    var i: usize = len;
                    while (i > cursor_pos) : (i -= 1) {
                        line_buf[i] = line_buf[i - 1];
                    }
                }
                line_buf[cursor_pos] = ch[0];
                len += 1;
                cursor_pos += 1;
                selected_idx = 0;
                renderMenuOrLine(prompt_prefix, line_buf[0..len], cursor_pos, &selected_idx);
                continue;
            }
        }
    }

    fn filterCommands(query: []const u8) []const SlashItem {
        var matches: [32]SlashItem = undefined;
        var count: usize = 0;
        for (AVAILABLE_COMMANDS) |item| {
            if (query.len == 0 or std.mem.startsWith(u8, item.cmd, query)) {
                matches[count] = item;
                count += 1;
                if (count >= 8) break; // Top 8 suggestions
            }
        }
        const slice: []const SlashItem = AVAILABLE_COMMANDS[0..@min(count, AVAILABLE_COMMANDS.len)];
        return slice;
    }

    fn renderMenuOrLine(prompt: []const u8, current_line: []const u8, cursor: usize, sel_idx: *usize) void {
        if (current_line.len > 0 and current_line[0] == '/' and !std.mem.containsAtLeast(u8, current_line, 1, " ")) {
            var matches: [16]SlashItem = undefined;
            var match_count: usize = 0;
            for (AVAILABLE_COMMANDS) |item| {
                if (std.mem.startsWith(u8, item.cmd, current_line)) {
                    matches[match_count] = item;
                    match_count += 1;
                    if (match_count >= 6) break;
                }
            }
            if (match_count > 0) {
                if (sel_idx.* >= match_count) sel_idx.* = match_count - 1;
                renderLine(prompt, current_line, cursor, matches[0..match_count], sel_idx.*);
                return;
            }
        }
        renderLine(prompt, current_line, cursor, null, 0);
    }

    fn renderLine(
        prompt: []const u8,
        current_line: []const u8,
        cursor: usize,
        menu_items: ?[]const SlashItem,
        selected: usize,
    ) void {
        var out: [4096]u8 = undefined;
        var out_len: usize = 0;

        // Clear from cursor down and return to line start
        const clear_prefix = "\r\x1b[K";
        @memcpy(out[out_len .. out_len + clear_prefix.len], clear_prefix);
        out_len += clear_prefix.len;

        // Prompt & text
        @memcpy(out[out_len .. out_len + prompt.len], prompt);
        out_len += prompt.len;

        @memcpy(out[out_len .. out_len + current_line.len], current_line);
        out_len += current_line.len;

        // Render popup autocomplete if active
        if (menu_items) |items| {
            var menu_buf: [2048]u8 = undefined;
            var m_cursor: usize = 0;

            const save_pos = "\x1b[s";
            @memcpy(menu_buf[m_cursor .. m_cursor + save_pos.len], save_pos);
            m_cursor += save_pos.len;

            for (items, 0..) |item, idx| {
                const is_sel = (idx == selected);
                const bg = if (is_sel) "\x1b[48;2;25;40;60m\x1b[38;2;83;182;255m ▶ " else "   ";
                const reset = "\x1b[0m";
                const line = std.fmt.bufPrint(
                    menu_buf[m_cursor..],
                    "\n\x1b[K  {s}{s:<18}\x1b[0m \x1b[38;2;139;157;175m{s}{s}",
                    .{ bg, item.cmd, item.desc, reset },
                ) catch break;
                m_cursor += line.len;
            }

            const restore_pos = "\x1b[u";
            if (m_cursor + restore_pos.len < menu_buf.len) {
                @memcpy(menu_buf[m_cursor .. m_cursor + restore_pos.len], restore_pos);
                m_cursor += restore_pos.len;
            }

            @memcpy(out[out_len .. out_len + m_cursor], menu_buf[0..m_cursor]);
            out_len += m_cursor;
        } else {
            const clear_below = "\x1b[s\n\x1b[J\x1b[u";
            @memcpy(out[out_len .. out_len + clear_below.len], clear_below);
            out_len += clear_below.len;
        }

        // Adjust cursor position if cursor < current_line.len
        if (cursor < current_line.len) {
            var move_buf: [16]u8 = undefined;
            const diff = current_line.len - cursor;
            const move_str = std.fmt.bufPrint(&move_buf, "\x1b[{d}D", .{diff}) catch "";
            @memcpy(out[out_len .. out_len + move_str.len], move_str);
            out_len += move_str.len;
        }

        _ = sys.Sys.write(1, @ptrCast(&out), out_len);
    }

    fn fallbackReadLine(buf: []u8) ?[]const u8 {
        var cursor: usize = 0;
        while (cursor < buf.len - 1) {
            var ch: [1]u8 = undefined;
            const r = sys.Sys.read(0, &ch, 1);
            if (r <= 0) return null;
            if (ch[0] == '\n') break;
            buf[cursor] = ch[0];
            cursor += 1;
        }
        return buf[0..cursor];
    }

    pub fn runInteractiveSettings(cfg_mgr: *config.ConfigManager) void {
        var raw_term: sys.Termios = undefined;
        var orig_term: sys.Termios = undefined;
        if (sys.Sys.tcgetattr(0, &orig_term) != 0) {
            cfg_mgr.renderSettingsMenu();
            return;
        }
        raw_term = orig_term;
        raw_term.c_lflag &= ~@as(c_ulong, 0x00000002 | 0x00000008);
        raw_term.c_cc[16] = 1;
        raw_term.c_cc[17] = 0;
        _ = sys.Sys.tcsetattr(0, 0, &raw_term);
        defer _ = sys.Sys.tcsetattr(0, 0, &orig_term);

        var selected_row: usize = 0;
        const total_rows: usize = 9;

        while (true) {
            renderSettingsScreen(cfg_mgr, selected_row);

            var ch: [4]u8 = undefined;
            const r = sys.Sys.read(0, @ptrCast(&ch), 4);
            if (r <= 0) break;

            if (ch[0] == 27) {
                if (r == 1) break; // ESC to exit settings
                if (ch[1] == '[') {
                    if (ch[2] == 'A') { // UP
                        if (selected_row > 0) selected_row -= 1;
                    } else if (ch[2] == 'B') { // DOWN
                        if (selected_row + 1 < total_rows) selected_row += 1;
                    } else if (ch[2] == 'C' or ch[2] == 'D') { // LEFT / RIGHT to toggle
                        toggleSetting(cfg_mgr, selected_row);
                    }
                }
            } else if (ch[0] == '\n' or ch[0] == '\r' or ch[0] == ' ') {
                toggleSetting(cfg_mgr, selected_row);
            } else if (ch[0] == 'q' or ch[0] == 'Q') {
                break;
            }
        }

        // Clean screen
        _ = sys.Sys.write(1, "\x1b[H\x1b[2J", 7);
    }

    fn toggleSetting(cfg_mgr: *config.ConfigManager, row: usize) void {
        switch (row) {
            0 => { // Autonomy Mode
                cfg_mgr.config.unbounded_autonomy = !cfg_mgr.config.unbounded_autonomy;
            },
            1 => { // Max Step Limit
                cfg_mgr.config.max_steps = switch (cfg_mgr.config.max_steps) {
                    5 => 15,
                    15 => 25,
                    25 => 50,
                    50 => 100,
                    100 => 0,
                    else => 5,
                };
            },
            2 => { // Context Strategy
                cfg_mgr.config.context_strategy = switch (cfg_mgr.config.context_strategy) {
                    .hierarchical_engrams => .rolling_window,
                    .rolling_window => .full_replay,
                    .full_replay => .hierarchical_engrams,
                };
            },
            3 => { // Auto-Compact Threshold
                cfg_mgr.config.auto_compact_threshold_pct = switch (cfg_mgr.config.auto_compact_threshold_pct) {
                    50 => 65,
                    65 => 75,
                    75 => 85,
                    85 => 90,
                    else => 50,
                };
            },
            4 => { // Pre-Compaction Dump
                cfg_mgr.config.pre_compact_dump = !cfg_mgr.config.pre_compact_dump;
            },
            5 => { // Tool Output Limit
                cfg_mgr.config.tool_output_limit = switch (cfg_mgr.config.tool_output_limit) {
                    .b512 => .b1024,
                    .b1024 => .b2048,
                    .b2048 => .b4096,
                    .b4096 => .b512,
                };
            },
            6 => { // Thinking Effort
                cfg_mgr.config.thinking_effort = switch (cfg_mgr.config.thinking_effort) {
                    .low => .medium,
                    .medium => .high,
                    .high => .max,
                    .max => .low,
                };
            },
            7 => { // Output Verbosity
                cfg_mgr.config.verbosity = switch (cfg_mgr.config.verbosity) {
                    .quiet => .normal,
                    .normal => .full_transcript,
                    .full_transcript => .quiet,
                };
            },
            8 => { // Sandbox
                cfg_mgr.config.sandbox_enabled = !cfg_mgr.config.sandbox_enabled;
            },
            else => {},
        }
        cfg_mgr.save();
    }

    fn renderSettingsScreen(cfg_mgr: *const config.ConfigManager, selected: usize) void {
        var buf: [4096]u8 = undefined;
        var cursor: usize = 0;

        const home = "\x1b[H\x1b[2J";
        @memcpy(buf[cursor .. cursor + home.len], home);
        cursor += home.len;

        const banner = std.fmt.bufPrint(
            buf[cursor..],
            \\
            \\{s}{s}  ⚙ ZIGAGENT INTERACTIVE SETTINGS PANEL{s}
            \\{s}  Use ↑/↓ arrow keys to navigate, Space/Enter/←/→ to toggle, Esc or 'q' to exit.{s}
            \\{s}─────────────────────────────────────────────────────────────────────────────{s}
            \\
        , .{ tui.TUI.C_CYAN, tui.TUI.C_BOLD, tui.TUI.C_RESET, tui.TUI.C_MUTED, tui.TUI.C_RESET, tui.TUI.C_BORDER, tui.TUI.C_RESET }) catch return;
        cursor += banner.len;

        var thresh_buf: [16]u8 = undefined;
        const thresh_str = std.fmt.bufPrint(&thresh_buf, "{d}%", .{cfg_mgr.config.auto_compact_threshold_pct}) catch "75%";

        const items = [_]struct { label: []const u8, val: []const u8 }{
            .{ .label = "Autonomy Mode", .val = if (cfg_mgr.config.unbounded_autonomy) "⚡ UNBOUNDED (Unlimited Autonomy)" else "Bounded Step Mode" },
            .{ .label = "Max Step Limit", .val = if (cfg_mgr.config.max_steps == 0) "Unlimited (0)" else if (cfg_mgr.config.max_steps == 15) "15 steps (Default)" else if (cfg_mgr.config.max_steps == 25) "25 steps" else if (cfg_mgr.config.max_steps == 50) "50 steps" else "100 steps" },
            .{ .label = "Context Strategy", .val = cfg_mgr.config.context_strategy.asString() },
            .{ .label = "Auto-Compact Threshold", .val = thresh_str },
            .{ .label = "Pre-Compaction Dump", .val = if (cfg_mgr.config.pre_compact_dump) "✔ Enabled (Auto-Checkpoint to Merkle Forest)" else "✘ Disabled" },
            .{ .label = "Tool Output Limit", .val = cfg_mgr.config.tool_output_limit.asString() },
            .{ .label = "Thinking / Reasoning", .val = cfg_mgr.config.thinking_effort.asString() },
            .{ .label = "Output Verbosity", .val = cfg_mgr.config.verbosity.asString() },
            .{ .label = "Execution Sandbox", .val = if (cfg_mgr.config.sandbox_enabled) "Enabled (Safe Filesystem & POSIX)" else "Disabled" },
        };

        for (items, 0..) |item, idx| {
            const is_sel = (idx == selected);
            const prefix = if (is_sel) "  \x1b[48;2;25;40;60m\x1b[38;2;83;182;255m ▶ " else "     ";
            const reset = "\x1b[0m";
            const val_color = if (is_sel) "\x1b[1;38;2;49;196;141m" else "\x1b[38;2;240;246;252m";

            const row = std.fmt.bufPrint(
                buf[cursor..],
                "{s}{s:<24} : {s}{s:<40}{s}\n",
                .{ prefix, item.label, val_color, item.val, reset },
            ) catch break;
            cursor += row.len;
        }

        const footer = std.fmt.bufPrint(
            buf[cursor..],
            \\{s}─────────────────────────────────────────────────────────────────────────────{s}
            \\{s}  Config Path: {s}{s}
            \\
        , .{ tui.TUI.C_BORDER, tui.TUI.C_RESET, tui.TUI.C_MUTED, cfg_mgr.config_path[0..cfg_mgr.config_path_len], tui.TUI.C_RESET }) catch return;
        cursor += footer.len;

        _ = sys.Sys.write(1, @ptrCast(&buf), cursor);
    }
};
