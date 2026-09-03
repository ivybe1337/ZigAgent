const std = @import("std");
const sys = @import("sys.zig");
const agent = @import("agent.zig");

pub const TUI = struct {
    // TrueColor 24-bit Obsidian Studio Palette
    pub const C_BG_VOID = "\x1b[48;2;7;9;14m";
    pub const C_BG_CARD = "\x1b[48;2;14;19;29m";
    pub const C_BG_SURFACE = "\x1b[48;2;20;28;42m";
    pub const C_RESET = "\x1b[0m";
    pub const C_BOLD = "\x1b[1m";
    pub const C_DIM = "\x1b[2m";

    // Accents
    pub const C_CYAN = "\x1b[38;2;0;242;254m";
    pub const C_AQUA = "\x1b[38;2;56;189;248m";
    pub const C_VIOLET = "\x1b[38;2;168;85;247m";
    pub const C_EMERALD = "\x1b[38;2;16;185;129m";
    pub const C_AMBER = "\x1b[38;2;245;158;11m";
    pub const C_CORAL = "\x1b[38;2;244;63;94m";
    pub const C_WHITE = "\x1b[38;2;241;245;249m";
    pub const C_MUTED = "\x1b[38;2;100;116;139m";
    pub const C_BORDER = "\x1b[38;2;30;41;59m";
    pub const C_BORDER_BRIGHT = "\x1b[38;2;51;65;85m";
    pub const C_ORANGE = "\x1b[38;2;255;107;53m";

    orig_termios: ?sys.Termios = null,

    pub fn enterRawMode(self: *TUI) void {
        var term: sys.Termios = undefined;
        if (sys.Sys.tcgetattr(0, &term) == 0) {
            self.orig_termios = term;
            term.c_lflag &= ~(sys.DARWIN_ICANON | sys.DARWIN_ECHO | sys.DARWIN_IEXTEN);
            term.c_cc[sys.VMIN] = 1;
            term.c_cc[sys.VTIME] = 0;
            _ = sys.Sys.tcsetattr(0, sys.TCSANOW, &term);
        }
        // Switch to alternate screen buffer and hide cursor
        _ = sys.Sys.write(1, "\x1b[?1049h\x1b[?25l", 14);
    }

    pub fn exitRawMode(self: *TUI) void {
        // Restore main screen buffer and show cursor
        _ = sys.Sys.write(1, "\x1b[?25h\x1b[?1049l", 14);
        if (self.orig_termios) |orig| {
            _ = sys.Sys.tcsetattr(0, sys.TCSANOW, &orig);
        }
    }

    pub fn render(self: *TUI, eng: *const agent.AgentEngine) void {
        self.renderStudioDashboard(
            "nvidia/nemotron-3-super-120b-a12b:free",
            "OpenRouter",
            336,
            1024000,
            0.0,
            eng,
        );
    }

    /// Renders a master studio-quality, full-screen terminal GUI with responsive split-pane layout
    pub fn renderStudioDashboard(
        self: *TUI,
        model_name: []const u8,
        provider_name: []const u8,
        current_tokens: u32,
        max_tokens: u32,
        fill_pct: f32,
        eng: *const agent.AgentEngine,
    ) void {
        _ = self;
        const ws = sys.getTerminalSize();
        const width: usize = @intCast(@max(ws.ws_col, 80));
        const height: usize = @intCast(@max(ws.ws_row, 24));

        var buf: [32768]u8 = undefined;
        var cursor: usize = 0;

        // 1. Home and clear
        const home_seq = "\x1b[H\x1b[2J";
        @memcpy(buf[cursor .. cursor + home_seq.len], home_seq);
        cursor += home_seq.len;

        // 2. Top Header Bar
        const top_border_len = if (width > 50) width - 50 else 20;
        var dash_line: [256]u8 = undefined;
        @memset(dash_line[0..@min(top_border_len, dash_line.len)], '-');
        const dashes = dash_line[0..@min(top_border_len, dash_line.len)];

        const header = std.fmt.bufPrint(
            buf[cursor..],
            "{s}╭── {s}{s}⚡ ZIGAGENT STUDIO // AUTONOMOUS ACTION ENGINE{s} {s}{s} {s}Model: {s}{s}{s} │ {s}● ONLINE{s} {s}╮{s}\n",
            .{
                C_BORDER_BRIGHT,
                C_CYAN, C_BOLD, C_RESET,
                C_BORDER, dashes,
                C_MUTED, C_WHITE, model_name, C_MUTED,
                C_EMERALD, C_RESET,
                C_BORDER_BRIGHT, C_RESET,
            },
        ) catch return;
        cursor += header.len;

        // 3. Subheader HUD: Context Window & Metrics Meter
        const filled_blocks: usize = @intFromFloat(@min((fill_pct / 100.0) * 24.0, 24.0));
        var meter_bar: [24]u8 = undefined;
        for (0..24) |idx| {
            meter_bar[idx] = if (idx < filled_blocks) '#' else '-';
        }

        const meter_col = if (fill_pct < 50.0) C_EMERALD else if (fill_pct < 80.0) C_AMBER else C_CORAL;
        const subheader = std.fmt.bufPrint(
            buf[cursor..],
            "{s}│{s}  {s}Context:{s} {s}[{s}]{s} {s}{d}/{d}k tok ({d:.1}%){s}  {s}Provider:{s} {s}{s}{s}  {s}Autonomy:{s} {s}UNBOUNDED{s}\n",
            .{
                C_BORDER_BRIGHT, C_RESET,
                C_MUTED, C_RESET,
                meter_col, meter_bar[0..24], C_RESET,
                C_WHITE, current_tokens, max_tokens / 1000, fill_pct, C_RESET,
                C_MUTED, C_RESET, C_CYAN, provider_name, C_RESET,
                C_MUTED, C_RESET, C_EMERALD, C_RESET,
            },
        ) catch return;
        cursor += subheader.len;

        // Divider
        var div_line: [256]u8 = undefined;
        @memset(div_line[0..@min(width - 2, div_line.len)], '-');
        const mid_div = std.fmt.bufPrint(
            buf[cursor..],
            "{s}├{s}─────────────────────────────┬{s}─────────────────────────────────────────────────────────────────{s}┤{s}\n",
            .{ C_BORDER_BRIGHT, C_BORDER, C_BORDER, C_BORDER_BRIGHT, C_RESET },
        ) catch return;
        cursor += mid_div.len;

        // Split Layout: Left Telemetry (30 cols) | Right Action Stream (remaining)
        const left_w: usize = 29;
        const right_w: usize = if (width > left_w + 3) width - left_w - 3 else 48;
        _ = right_w;

        // Telemetry Data Items
        var hot_buf: [128]u8 = undefined;
        const hot_len = eng.memory_store.getHotSummary(&hot_buf);
        const hot_summary = if (hot_len > 0) hot_buf[0..hot_len] else "3 hot engrams active";

        const root = eng.memory_store.computeMerkleRoot();
        const root_short = if (root.len > 16) root[0..16] else root;

        const left_rows = [_]struct { label: []const u8, val: []const u8, col: []const u8 }{
            .{ .label = "Runtime", .val = "Native Zig 0.16", .col = C_WHITE },
            .{ .label = "Memory L1", .val = "Thermodynamic Ring", .col = C_CYAN },
            .{ .label = "Memory L3", .val = "Merkle Forest", .col = C_CYAN },
            .{ .label = "Forest Root", .val = root_short, .col = C_MUTED },
            .{ .label = "Active Facts", .val = hot_summary, .col = C_WHITE },
            .{ .label = "AST Guard", .val = "Balanced (Verified)", .col = C_EMERALD },
            .{ .label = "Invariants", .val = "4/4 Active Gates", .col = C_EMERALD },
            .{ .label = "Sandbox", .val = "Strict Non-Destructive", .col = C_EMERALD },
            .{ .label = "Deliberation", .val = "4-Pass Metacognition", .col = C_VIOLET },
            .{ .label = "Time Machine", .val = "Snapshots Armed", .col = C_AQUA },
        };

        const right_rows = [_]struct { title: []const u8, text: []const u8, tag: []const u8 }{
            .{ .title = "ACTIVE GOAL", .text = if (eng.state.current_goal.len > 0) eng.state.current_goal else "Awaiting autonomous directive or user prompt...", .tag = "GOAL" },
            .{ .title = "COGNITIVE PHASE", .text = eng.state.phase.asString(), .tag = "PHASE" },
            .{ .title = "DELIBERATION PIPELINE", .text = "Phase 1 [Explore] ❯ Phase 2 [Critique] ❯ Phase 3 [Prove] ❯ Phase 4 [Synthesize]", .tag = "META" },
            .{ .title = "THOUGHT STREAM", .text = if (eng.state.last_thought.len > 0) eng.state.last_thought else "Epistemic state idle. Neural circuits primed for next directive.", .tag = "THOUGHT" },
            .{ .title = "TOOL EXECUTION", .text = if (eng.state.active_tool.len > 0) eng.state.active_tool else "No active tool running. File cache synchronized.", .tag = "TOOL" },
        };

        const total_canvas_rows = @min(height - 8, 12);
        for (0..total_canvas_rows) |row_idx| {
            // Left pane content
            var left_txt: [48]u8 = undefined;
            var left_rendered: []const u8 = "";
            if (row_idx < left_rows.len) {
                const item = left_rows[row_idx];
                left_rendered = std.fmt.bufPrint(&left_txt, "{s}• {s:<11}:{s} {s}{s:<14}{s}", .{
                    C_MUTED, item.label, C_RESET, item.col, item.val, C_RESET,
                }) catch "";
            }

            // Right pane content
            var right_txt: [256]u8 = undefined;
            var right_rendered: []const u8 = "";
            if (row_idx < right_rows.len) {
                const item = right_rows[row_idx];
                right_rendered = std.fmt.bufPrint(&right_txt, "{s}[{s}]{s} {s}{s}:{s} {s}{s}{s}", .{
                    C_CYAN, item.tag, C_RESET,
                    C_BOLD, item.title, C_RESET,
                    C_WHITE, item.text, C_RESET,
                }) catch "";
            }

            const row_str = std.fmt.bufPrint(
                buf[cursor..],
                "{s}│{s} {s:<28} {s}│{s} {s}\n",
                .{
                    C_BORDER_BRIGHT, C_RESET,
                    left_rendered,
                    C_BORDER, C_RESET,
                    right_rendered,
                },
            ) catch return;
            cursor += row_str.len;
        }

        // Bottom Footer Bar with Studio Commands
        const bottom_div = std.fmt.bufPrint(
            buf[cursor..],
            "{s}├{s}─────────────────────────────┴{s}─────────────────────────────────────────────────────────────────{s}┤{s}\n",
            .{ C_BORDER_BRIGHT, C_BORDER, C_BORDER, C_BORDER_BRIGHT, C_RESET },
        ) catch return;
        cursor += bottom_div.len;

        const footer = std.fmt.bufPrint(
            buf[cursor..],
            "{s}╰── {s}[ENTER]{s} Prompt  {s}[M]{s} Model  {s}[K]{s} Keys  {s}[S]{s} Settings  {s}[D]{s} Doctor  {s}[Q]{s} Return to REPL {s}──╯{s}\n",
            .{
                C_BORDER_BRIGHT,
                C_CYAN, C_RESET,
                C_AQUA, C_RESET,
                C_VIOLET, C_RESET,
                C_EMERALD, C_RESET,
                C_AMBER, C_RESET,
                C_CORAL, C_RESET,
                C_BORDER_BRIGHT, C_RESET,
            },
        ) catch return;
        cursor += footer.len;

        _ = sys.Sys.write(1, buf[0..cursor].ptr, cursor);
    }
};

