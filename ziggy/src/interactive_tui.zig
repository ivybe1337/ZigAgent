const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const config = @import("config.zig");
const tips = @import("tips.zig");

pub const SlashItem = struct {
    cmd: []const u8,
    desc: []const u8,
};

pub const AVAILABLE_COMMANDS = [_]SlashItem{
    .{ .cmd = "/model", .desc = "Switch or select active model via interactive picker" },
    .{ .cmd = "/models", .desc = "Browse all frontier & stealth models" },
    .{ .cmd = "/keys", .desc = "View AI provider authentication status" },
    .{ .cmd = "/key", .desc = "Set provider API key: /key openrouter <key>" },
    .{ .cmd = "/provider", .desc = "Switch active provider: /provider openrouter" },
    .{ .cmd = "/reset", .desc = "Clear conversation history & start fresh dialogue" },
    .{ .cmd = "/settings", .desc = "Interactive settings & preferences panel" },
    .{ .cmd = "/doctor", .desc = "Audit toolchains (Zig, Git, cURL, Bun, Python3, Clang)" },
    .{ .cmd = "/help", .desc = "Show all command references and capabilities" },
    .{ .cmd = "/minds_eye", .desc = "Spatial vision screen capture and computer use" },
    .{ .cmd = "/thermo", .desc = "Thermodynamic memory entropy dissipation" },
    .{ .cmd = "/bifurcate", .desc = "Bifurcate exploration tree into parallel paths" },
    .{ .cmd = "/introspect", .desc = "Introspective metacognitive self-critique" },
    .{ .cmd = "/morphic", .desc = "Morphogenetic codebase adaptation" },
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
    .{ .cmd = "/compact", .desc = "Targeted context compaction" },
    .{ .cmd = "/speculate", .desc = "Multi-candidate speculative plan evaluator" },
    .{ .cmd = "/council", .desc = "3-Lens consensus evaluation (Security/Perf/Arch)" },
    .{ .cmd = "/ast", .desc = "Verify structural balanced delimiter integrity" },
    .{ .cmd = "/snapshot", .desc = "Create point-in-time state checkpoint" },
    .{ .cmd = "/rollback", .desc = "Revert workspace to previous state snapshot" },
    .{ .cmd = "/timeline", .desc = "Inspect state snapshots in Time Machine" },
    .{ .cmd = "/ledger", .desc = "Cross-agent continuity ledger" },
    .{ .cmd = "/inbox", .desc = "Inter-agent mailbox inbox" },
    .{ .cmd = "/clear", .desc = "Clear terminal screen" },
    .{ .cmd = "/exit", .desc = "Exit ZigAgent CLI" },
};

pub const COMMON_PROMPTS = [_][]const u8{
    "refactor ",
    "debug and fix ",
    "explain how ",
    "build and test ",
    "analyze the architecture of ",
    "optimize performance of ",
    "implement feature ",
    "write unit tests for ",
    "review code in ",
    "document the API in ",
    "check git status and diff",
    "search for ",
};

pub const InteractiveTUI = struct {
    fn refreshLine(prompt_prefix: []const u8, text: []const u8, cursor_pos: usize) void {
        _ = sys.Sys.write(1, "\r\x1b[2K", 5);
        _ = sys.Sys.write(1, prompt_prefix.ptr, prompt_prefix.len);
        _ = sys.Sys.write(1, text.ptr, text.len);
        if (text.len > cursor_pos) {
            var move_buf: [16]u8 = undefined;
            const move_str = std.fmt.bufPrint(&move_buf, "\x1b[{d}D", .{text.len - cursor_pos}) catch "";
            if (move_str.len > 0) {
                _ = sys.Sys.write(1, move_str.ptr, move_str.len);
            }
        }
    }

    /// Interactive terminal input reader with full arrow navigation, editing, TAB autocomplete & history
    pub fn readInputWithAutocomplete(
        allocator: std.mem.Allocator,
        prompt_prefix: []const u8,
        out_buf: []u8,
        history: *std.ArrayList([]const u8),
    ) ?[]const u8 {
        _ = sys.Sys.write(1, prompt_prefix.ptr, prompt_prefix.len);

        var term_orig: sys.Termios = undefined;
        const is_tty = (sys.Sys.tcgetattr(0, &term_orig) == 0);

        if (is_tty) {
            var term_raw = term_orig;
            term_raw.c_lflag &= ~(sys.DARWIN_ICANON | sys.DARWIN_ECHO);
            term_raw.c_cc[sys.VMIN] = 0;
            term_raw.c_cc[sys.VTIME] = 60; // 6.0s timeout to circulate tips while sitting idle
            _ = sys.Sys.tcsetattr(0, sys.TCSANOW, &term_raw);
        }
        defer if (is_tty) {
            _ = sys.Sys.tcsetattr(0, sys.TCSANOW, &term_orig);
        };

        _ = sys.Sys.write(1, "\x1b[?2004h", 8);
        defer _ = sys.Sys.write(1, "\x1b[?2004l", 8);

        var buf: [65536]u8 = undefined;
        var total_len: usize = 0;
        var cursor_pos: usize = 0;
        var in_paste = false;

        var history_idx: isize = @intCast(history.items.len);
        var esc_buf: [16]u8 = undefined;
        var esc_len: usize = 0;

        while (total_len < buf.len - 1) {
            var ch: [1]u8 = undefined;
            const r = sys.Sys.read(0, &ch, 1);
            if (r <= 0) {
                if (!is_tty) {
                    if (total_len == 0) return null;
                    break;
                }
                // Idle timer triggered: circulate an informative tip if user is sitting idle at empty prompt
                if (total_len == 0 and !in_paste) {
                    const tip = tips.getNextTip();
                    _ = sys.Sys.write(1, "\r\x1b[K\x1b[38;2;120;140;165m💡 Tip: \x1b[38;2;160;185;210m", 45);
                    _ = sys.Sys.write(1, tip.ptr, tip.len);
                    _ = sys.Sys.write(1, "\x1b[0m\r\n", 6);
                    _ = sys.Sys.write(1, prompt_prefix.ptr, prompt_prefix.len);
                }
                continue;
            }

            // 1. Bracketed paste & escape sequences (arrow keys, home, end, delete)
            if (esc_len > 0 or ch[0] == 27) {
                if (esc_len < esc_buf.len) {
                    esc_buf[esc_len] = ch[0];
                    esc_len += 1;
                }
                const cur_esc = esc_buf[0..esc_len];

                // Bracketed paste detection
                if (std.mem.eql(u8, cur_esc, "\x1b[200~")) {
                    in_paste = true;
                    esc_len = 0;
                    continue;
                } else if (std.mem.eql(u8, cur_esc, "\x1b[201~")) {
                    in_paste = false;
                    esc_len = 0;
                    continue;
                }

                // 3-byte escape sequences: Arrow keys, Home, End
                if (esc_len == 3 and cur_esc[1] == '[') {
                    // Arrow UP (history previous)
                    if (cur_esc[2] == 'A') {
                        if (history.items.len > 0 and history_idx > 0) {
                            history_idx -= 1;
                            const prev = history.items[@intCast(history_idx)];
                            @memcpy(buf[0..prev.len], prev);
                            total_len = prev.len;
                            cursor_pos = prev.len;
                            refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                        }
                        esc_len = 0;
                        continue;
                    }
                    // Arrow DOWN (history next)
                    if (cur_esc[2] == 'B') {
                        if (history.items.len > 0 and history_idx < @as(isize, @intCast(history.items.len)) - 1) {
                            history_idx += 1;
                            const next = history.items[@intCast(history_idx)];
                            @memcpy(buf[0..next.len], next);
                            total_len = next.len;
                            cursor_pos = next.len;
                            refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                        } else if (history_idx >= @as(isize, @intCast(history.items.len)) - 1) {
                            history_idx = @intCast(history.items.len);
                            total_len = 0;
                            cursor_pos = 0;
                            refreshLine(prompt_prefix, "", 0);
                        }
                        esc_len = 0;
                        continue;
                    }
                    // Arrow RIGHT
                    if (cur_esc[2] == 'C') {
                        if (cursor_pos < total_len) {
                            cursor_pos += 1;
                            _ = sys.Sys.write(1, "\x1b[C", 3);
                        }
                        esc_len = 0;
                        continue;
                    }
                    // Arrow LEFT
                    if (cur_esc[2] == 'D') {
                        if (cursor_pos > 0) {
                            cursor_pos -= 1;
                            _ = sys.Sys.write(1, "\x1b[D", 3);
                        }
                        esc_len = 0;
                        continue;
                    }
                    // Home
                    if (cur_esc[2] == 'H') {
                        cursor_pos = 0;
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                        esc_len = 0;
                        continue;
                    }
                    // End
                    if (cur_esc[2] == 'F') {
                        cursor_pos = total_len;
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                        esc_len = 0;
                        continue;
                    }
                }

                // 4-byte escape sequences: Delete (\x1b[3~), Home (\x1b[1~), End (\x1b[4~)
                if (esc_len == 4 and cur_esc[1] == '[') {
                    if (cur_esc[2] == '3' and cur_esc[3] == '~') { // Delete
                        if (cursor_pos < total_len) {
                            for (cursor_pos..total_len - 1) |idx| {
                                buf[idx] = buf[idx + 1];
                            }
                            total_len -= 1;
                            refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                        }
                        esc_len = 0;
                        continue;
                    } else if (cur_esc[2] == '1' and cur_esc[3] == '~') { // Home
                        cursor_pos = 0;
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                        esc_len = 0;
                        continue;
                    } else if (cur_esc[2] == '4' and cur_esc[3] == '~') { // End
                        cursor_pos = total_len;
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                        esc_len = 0;
                        continue;
                    }
                }

                if (esc_len >= 6 or (esc_len >= 2 and esc_buf[1] != '[')) {
                    esc_len = 0;
                    continue;
                }
                continue;
            }

            // 2. Return / Enter -> Submit prompt
            if (!in_paste and (ch[0] == '\n' or ch[0] == '\r')) {
                if (is_tty) _ = sys.Sys.write(1, "\r\n", 2);
                break;
            }

            // 3. Backspace (0x7f or 0x08)
            if (!in_paste and (ch[0] == 127 or ch[0] == 8)) {
                if (cursor_pos > 0) {
                    for (cursor_pos - 1..total_len - 1) |idx| {
                        buf[idx] = buf[idx + 1];
                    }
                    cursor_pos -= 1;
                    total_len -= 1;
                    refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                }
                continue;
            }

            // 4. Ctrl+C
            if (ch[0] == 3) {
                if (is_tty) _ = sys.Sys.write(1, "^C\r\n", 4);
                return "";
            }

            // 5. Ctrl+A (Home)
            if (ch[0] == 1) {
                cursor_pos = 0;
                refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                continue;
            }

            // 6. Ctrl+E (End)
            if (ch[0] == 5) {
                cursor_pos = total_len;
                refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                continue;
            }

            // 7. Ctrl+U (Clear line)
            if (ch[0] == 21) {
                cursor_pos = 0;
                total_len = 0;
                refreshLine(prompt_prefix, "", 0);
                continue;
            }

            // 8. Ctrl+K (Kill to end of line)
            if (ch[0] == 11) {
                total_len = cursor_pos;
                refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                continue;
            }

            // 9. Ctrl+W (Delete previous word)
            if (ch[0] == 23) {
                while (cursor_pos > 0 and buf[cursor_pos - 1] == ' ') {
                    for (cursor_pos - 1..total_len - 1) |idx| buf[idx] = buf[idx + 1];
                    cursor_pos -= 1;
                    total_len -= 1;
                }
                while (cursor_pos > 0 and buf[cursor_pos - 1] != ' ') {
                    for (cursor_pos - 1..total_len - 1) |idx| buf[idx] = buf[idx + 1];
                    cursor_pos -= 1;
                    total_len -= 1;
                }
                refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                continue;
            }

            // 10. TAB -> Auto Complete Suggestions (/ commands & prompt box)
            if (!in_paste and ch[0] == '\t') {
                const cur_text = buf[0..cursor_pos];
                if (std.mem.startsWith(u8, cur_text, "/")) {
                    var matches: [16][]const u8 = undefined;
                    var match_count: usize = 0;
                    for (AVAILABLE_COMMANDS) |item| {
                        if (std.mem.startsWith(u8, item.cmd, cur_text)) {
                            if (match_count < matches.len) {
                                matches[match_count] = item.cmd;
                                match_count += 1;
                            }
                        }
                    }

                    if (match_count == 1) {
                        const completed = matches[0];
                        @memcpy(buf[0..completed.len], completed);
                        buf[completed.len] = ' ';
                        total_len = completed.len + 1;
                        cursor_pos = total_len;
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                    } else if (match_count > 1 and is_tty) {
                        _ = sys.Sys.write(1, "\r\n\x1b[38;2;139;157;175m  Suggestions: \x1b[0m", 37);
                        for (matches[0..match_count]) |m| {
                            _ = sys.Sys.write(1, "\x1b[38;2;0;242;254m", 16);
                            _ = sys.Sys.write(1, m.ptr, m.len);
                            _ = sys.Sys.write(1, "\x1b[0m  ", 6);
                        }
                        _ = sys.Sys.write(1, "\r\n", 2);
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                    }
                } else {
                    var prompt_matches: [8][]const u8 = undefined;
                    var p_count: usize = 0;
                    for (COMMON_PROMPTS) |prompt| {
                        if (std.mem.startsWith(u8, prompt, cur_text)) {
                            if (p_count < prompt_matches.len) {
                                prompt_matches[p_count] = prompt;
                                p_count += 1;
                            }
                        }
                    }

                    if (p_count == 1) {
                        const completed = prompt_matches[0];
                        @memcpy(buf[0..completed.len], completed);
                        total_len = completed.len;
                        cursor_pos = completed.len;
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                    } else if (p_count > 1 and is_tty) {
                        _ = sys.Sys.write(1, "\r\n\x1b[38;2;139;157;175m  Suggestions: \x1b[0m", 37);
                        for (prompt_matches[0..p_count]) |m| {
                            _ = sys.Sys.write(1, "\x1b[38;2;49;196;141m", 17);
                            _ = sys.Sys.write(1, m.ptr, m.len);
                            _ = sys.Sys.write(1, "\x1b[0m  ", 6);
                        }
                        _ = sys.Sys.write(1, "\r\n", 2);
                        refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
                    }
                }
                continue;
            }

            // 11. Normal character insertion (supports insertion in middle of line)
            if (cursor_pos == total_len) {
                buf[cursor_pos] = if (ch[0] == '\r') '\n' else ch[0];
                cursor_pos += 1;
                total_len += 1;
                if (is_tty) _ = sys.Sys.write(1, &ch, 1);
            } else {
                var idx = total_len;
                while (idx > cursor_pos) : (idx -= 1) {
                    buf[idx] = buf[idx - 1];
                }
                buf[cursor_pos] = if (ch[0] == '\r') '\n' else ch[0];
                cursor_pos += 1;
                total_len += 1;
                refreshLine(prompt_prefix, buf[0..total_len], cursor_pos);
            }
        }
        buf[total_len] = 0;

        const raw_slice = buf[0..total_len];
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
            _ = sys.Sys.write(1, "\x1b[?1049h\x1b[?25l", 14);
        }
        defer if (has_tty) {
            _ = sys.Sys.write(1, "\x1b[?25h\x1b[?1049l", 14);
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
            \\\x1b[H\x1b[2J{s}╭─────────────────────────────────────────────────────────────────────────────╮{s}
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
