const std = @import("std");
const sys = @import("sys.zig");
const agent = @import("agent.zig");

pub const TUI = struct {
    // ANSI 24-bit TrueColor Palettes
    pub const C_BG = "\x1b[48;2;11;15;20m";
    pub const C_PANEL = "\x1b[48;2;18;25;34m";
    pub const C_RESET = "\x1b[0m";
    pub const C_BOLD = "\x1b[1m";
    pub const C_DIM = "\x1b[2m";

    pub const C_AQUA = "\x1b[38;2;49;196;141m";
    pub const C_ORANGE = "\x1b[38;2;255;107;53m";
    pub const C_CYAN = "\x1b[38;2;83;182;255m";
    pub const C_WHITE = "\x1b[38;2;240;246;252m";
    pub const C_MUTED = "\x1b[38;2;139;157;175m";
    pub const C_BORDER = "\x1b[38;2;40;56;75m";

    orig_termios: ?sys.Termios = null,

    pub fn enterRawMode(self: *TUI) void {
        var term: sys.Termios = undefined;
        if (sys.Sys.tcgetattr(0, &term) == 0) {
            self.orig_termios = term;
            term.c_lflag &= ~@as(c_ulong, 0x00000002 | 0x00000008); // ICANON | ECHO
            _ = sys.Sys.tcsetattr(0, 0, &term);
        }
        // Switch to alternate screen buffer and hide cursor
        _ = sys.Sys.write(1, "\x1b[?1049h\x1b[?25l", 14);
    }

    pub fn exitRawMode(self: *TUI) void {
        if (self.orig_termios) |orig| {
            _ = sys.Sys.tcsetattr(0, 0, &orig);
        }
        // Restore main screen buffer and show cursor
        _ = sys.Sys.write(1, "\x1b[?1049l\x1b[?25h", 14);
    }

    pub fn render(self: *TUI, eng: *const agent.AgentEngine) void {
        _ = self;
        var buf: [8192]u8 = undefined;
        var cursor: usize = 0;

        // Clear and home cursor
        const clear_cmd = "\x1b[H\x1b[2J";
        @memcpy(buf[cursor .. cursor + clear_cmd.len], clear_cmd);
        cursor += clear_cmd.len;

        // Banner
        const banner = std.fmt.bufPrint(
            buf[cursor..],
            "{s}{s}  ⚡ ZIGAGENT // NE PLUS ULTRA RUNTIME {s}{s} [NATIVE COGNITIVE SUITE]{s}\n{s}─────────────────────────────────────────────────────────────────────────────{s}\n",
            .{ C_AQUA, C_BOLD, C_RESET, C_DIM, C_RESET, C_BORDER, C_RESET },
        ) catch return;
        cursor += banner.len;

        // Telemetry HUD
        const conf_pct: u32 = @intFromFloat(eng.state.confidence * 100.0);
        var conf_bar: [20]u8 = undefined;
        const filled = (conf_pct * 20) / 100;
        for (0..20) |idx| {
            conf_bar[idx] = if (idx < filled) '#' else '.';
        }

        const hud = std.fmt.bufPrint(
            buf[cursor..],
            "{s}  PHASE: {s}{s}{s:<18}{s} │ STEP: {s}{d:<3}{s} │ CONFIDENCE: {s}[{s}] {d:>3}%{s}\n{s}─────────────────────────────────────────────────────────────────────────────{s}\n",
            .{
                C_MUTED, C_AQUA, C_BOLD, eng.state.phase.asString(),
                C_BORDER, C_WHITE, eng.state.step,
                C_BORDER, C_ORANGE, conf_bar[0..20], conf_pct, C_RESET,
                C_BORDER, C_RESET,
            },
        ) catch return;
        cursor += hud.len;

        // Goal Box
        const goal = std.fmt.bufPrint(
            buf[cursor..],
            "{s}  ACTIVE GOAL:{s} {s}{s}{s}\n\n{s}  [COGNITIVE STREAM]{s}\n  {s}Thought:{s} {s}\n",
            .{ C_CYAN, C_RESET, C_WHITE, eng.state.current_goal, C_RESET, C_ORANGE, C_RESET, C_MUTED, C_WHITE, eng.state.last_thought },
        ) catch return;
        cursor += goal.len;

        if (eng.state.active_tool.len > 0) {
            const tool = std.fmt.bufPrint(
                buf[cursor..],
                "  {s}Tool Executing: {s}{s}{s}\n",
                .{ C_MUTED, C_AQUA, eng.state.active_tool, C_RESET },
            ) catch return;
            cursor += tool.len;
        }

        // Memory Thermodynamic Telemetry
        const mem_header = std.fmt.bufPrint(
            buf[cursor..],
            "\n{s}  [THERMODYNAMIC MEMORY L1/L3 MERKLE FOREST]{s}\n",
            .{ C_AQUA, C_RESET },
        ) catch return;
        cursor += mem_header.len;

        var mem_buf: [1024]u8 = undefined;
        const mem_len = eng.memory_store.getHotSummary(&mem_buf);
        if (mem_len > 0) {
            const mem_slice = std.fmt.bufPrint(
                buf[cursor..],
                "{s}{s}{s}",
                .{ C_MUTED, mem_buf[0..mem_len], C_RESET },
            ) catch return;
            cursor += mem_slice.len;
        } else {
            const mem_empty = std.fmt.bufPrint(
                buf[cursor..],
                "  {s}• Active Ring: Clean / Ready for engrams{s}\n",
                .{ C_DIM, C_RESET },
            ) catch return;
            cursor += mem_empty.len;
        }

        // Keybindings Footer
        const footer = std.fmt.bufPrint(
            buf[cursor..],
            "\n{s}─────────────────────────────────────────────────────────────────────────────{s}\n  {s}[SPACE]{s} Step  {s}[R]{s} Run Goal  {s}[Q]{s} Exit\n",
            .{ C_BORDER, C_RESET, C_ORANGE, C_RESET, C_AQUA, C_RESET, C_CYAN, C_RESET },
        ) catch return;
        cursor += footer.len;

        _ = sys.Sys.write(1, buf[0..cursor].ptr, cursor);
    }
};
