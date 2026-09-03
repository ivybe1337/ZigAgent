const std = @import("std");
const sys = @import("sys.zig");
const auth = @import("auth.zig");
const tui = @import("tui.zig");

pub const VerbosityMode = enum {
    quiet,
    normal,
    full_transcript,

    pub fn asString(self: VerbosityMode) []const u8 {
        return switch (self) {
            .quiet => "quiet",
            .normal => "normal",
            .full_transcript => "full_transcript",
        };
    }
};

pub const ThinkingEffort = enum {
    low,
    medium,
    high,
    max,

    pub fn asString(self: ThinkingEffort) []const u8 {
        return switch (self) {
            .low => "low",
            .medium => "medium",
            .high => "high",
            .max => "max",
        };
    }
};

pub const ContextStrategy = enum {
    hierarchical_engrams,
    rolling_window,
    full_replay,

    pub fn asString(self: ContextStrategy) []const u8 {
        return switch (self) {
            .hierarchical_engrams => "Hierarchical Engrams (Lowest Tokens)",
            .rolling_window => "Rolling Window (Recent turns)",
            .full_replay => "Full Replay (High tokens)",
        };
    }
};

pub const ToolOutputLimit = enum {
    b512,
    b1024,
    b2048,
    b4096,

    pub fn bytes(self: ToolOutputLimit) usize {
        return switch (self) {
            .b512 => 512,
            .b1024 => 1024,
            .b2048 => 2048,
            .b4096 => 4096,
        };
    }

    pub fn asString(self: ToolOutputLimit) []const u8 {
        return switch (self) {
            .b512 => "512 bytes",
            .b1024 => "1 KB",
            .b2048 => "2 KB",
            .b4096 => "4 KB",
        };
    }
};

pub const AgentConfig = struct {
    verbosity: VerbosityMode = .quiet,
    thinking_effort: ThinkingEffort = .high,
    context_strategy: ContextStrategy = .hierarchical_engrams,
    tool_output_limit: ToolOutputLimit = .b1024,
    pre_compact_dump: bool = true,
    auto_compact_threshold_pct: u32 = 75,
    token_warning_threshold_pct: u32 = 80,
    sandbox_enabled: bool = true,
    unbounded_autonomy: bool = false,
    max_steps: u32 = 15,
    stream_output: bool = true,
    telemetry_enabled: bool = false,
    active_agent_profile: [64]u8 = [_]u8{0} ** 64,
    default_model: [128]u8 = [_]u8{0} ** 128,
};

pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    config: AgentConfig,
    config_path: [512]u8,
    config_path_len: usize,

    pub fn init(allocator: std.mem.Allocator) ConfigManager {
        var self = ConfigManager{
            .allocator = allocator,
            .config = .{},
            .config_path = [_]u8{0} ** 512,
            .config_path_len = 0,
        };

        var home_path: [256]u8 = undefined;
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        @memcpy(home_path[0..home_len], home[0..home_len]);

        const path = std.fmt.bufPrint(&self.config_path, "{s}/.ziggy/config.json", .{home_path[0..home_len]}) catch ".ziggy/config.json";
        self.config_path_len = path.len;

        _ = std.fmt.bufPrint(&self.config.active_agent_profile, "default", .{}) catch "";
        _ = std.fmt.bufPrint(&self.config.default_model, "nvidia/nemotron-3-super-120b-a12b:free", .{}) catch "";
        self.load();

        return self;
    }

    pub fn save(self: *const ConfigManager) void {
        var buf: [2048]u8 = undefined;
        const json = std.fmt.bufPrint(
            &buf,
            \\{{
            \\  "verbosity": "{s}",
            \\  "thinking_effort": "{s}",
            \\  "context_strategy": "{s}",
            \\  "tool_output_limit": "{s}",
            \\  "pre_compact_dump": {s},
            \\  "auto_compact_threshold_pct": {d},
            \\  "unbounded_autonomy": {s},
            \\  "max_steps": {d},
            \\  "sandbox_enabled": {s},
            \\  "stream_output": {s},
            \\  "active_agent_profile": "{s}",
            \\  "default_model": "{s}"
            \\}}
            \\
        , .{
            self.config.verbosity.asString(),
            self.config.thinking_effort.asString(),
            @tagName(self.config.context_strategy),
            @tagName(self.config.tool_output_limit),
            if (self.config.pre_compact_dump) "true" else "false",
            self.config.auto_compact_threshold_pct,
            if (self.config.unbounded_autonomy) "true" else "false",
            self.config.max_steps,
            if (self.config.sandbox_enabled) "true" else "false",
            if (self.config.stream_output) "true" else "false",
            std.mem.sliceTo(&self.config.active_agent_profile, 0),
            std.mem.sliceTo(&self.config.default_model, 0),
        }) catch return;

        const path = self.config_path[0..self.config_path_len];
        _ = sys.writeEntireFile(path, json);
    }

    pub fn load(self: *ConfigManager) void {
        const path = self.config_path[0..self.config_path_len];
        const content = sys.readEntireFile(self.allocator, path, 4096) orelse return;
        defer self.allocator.free(content);

        if (std.mem.indexOf(u8, content, "\"verbosity\": \"quiet\"") != null) self.config.verbosity = .quiet;
        if (std.mem.indexOf(u8, content, "\"verbosity\": \"normal\"") != null) self.config.verbosity = .normal;
        if (std.mem.indexOf(u8, content, "\"verbosity\": \"full_transcript\"") != null) self.config.verbosity = .full_transcript;

        if (std.mem.indexOf(u8, content, "\"unbounded_autonomy\": true") != null) self.config.unbounded_autonomy = true;
        if (std.mem.indexOf(u8, content, "\"unbounded_autonomy\": false") != null) self.config.unbounded_autonomy = false;

        if (std.mem.indexOf(u8, content, "\"pre_compact_dump\": true") != null) self.config.pre_compact_dump = true;
        if (std.mem.indexOf(u8, content, "\"pre_compact_dump\": false") != null) self.config.pre_compact_dump = false;

        if (std.mem.indexOf(u8, content, "\"thinking_effort\": \"low\"") != null) self.config.thinking_effort = .low;
        if (std.mem.indexOf(u8, content, "\"thinking_effort\": \"medium\"") != null) self.config.thinking_effort = .medium;
        if (std.mem.indexOf(u8, content, "\"thinking_effort\": \"high\"") != null) self.config.thinking_effort = .high;
        if (std.mem.indexOf(u8, content, "\"thinking_effort\": \"max\"") != null) self.config.thinking_effort = .max;

        if (std.mem.indexOf(u8, content, "\"context_strategy\": \"hierarchical_engrams\"") != null) self.config.context_strategy = .hierarchical_engrams;
        if (std.mem.indexOf(u8, content, "\"context_strategy\": \"rolling_window\"") != null) self.config.context_strategy = .rolling_window;
        if (std.mem.indexOf(u8, content, "\"context_strategy\": \"full_replay\"") != null) self.config.context_strategy = .full_replay;

        if (std.mem.indexOf(u8, content, "\"tool_output_limit\": \"b512\"") != null) self.config.tool_output_limit = .b512;
        if (std.mem.indexOf(u8, content, "\"tool_output_limit\": \"b1024\"") != null) self.config.tool_output_limit = .b1024;
        if (std.mem.indexOf(u8, content, "\"tool_output_limit\": \"b2048\"") != null) self.config.tool_output_limit = .b2048;
        if (std.mem.indexOf(u8, content, "\"tool_output_limit\": \"b4096\"") != null) self.config.tool_output_limit = .b4096;

        if (std.mem.indexOf(u8, content, "\"default_model\"")) |idx| {
            const after_key = content[idx + 15 ..];
            if (std.mem.indexOfScalar(u8, after_key, '"')) |q1| {
                const val_start = q1 + 1;
                if (std.mem.indexOfScalar(u8, after_key[val_start..], '"')) |q2_rel| {
                    const val = after_key[val_start .. val_start + q2_rel];
                    if (val.len > 0) {
                        const copy_len = @min(val.len, self.config.default_model.len - 1);
                        @memcpy(self.config.default_model[0..copy_len], val[0..copy_len]);
                        self.config.default_model[copy_len] = 0;
                    }
                }
            }
        }
    }

    pub fn renderSettingsMenu(self: *const ConfigManager) void {
        std.debug.print(
            \\
            \\{s}=== ZIGAGENT SETTINGS & CONFIGURATION PANEL ==={s}
            \\  [1] Autonomy Mode:           {s}{s}{s} (unbounded = infinite loop)
            \\  [2] Max Step Limit:          {s}{d} steps{s}
            \\  [3] Context Strategy:        {s}{s:<34}{s} (hierarchical engrams = lowest tokens)
            \\  [4] Auto-Compact Threshold:  {s}{d}%{s} (context window warning/flush)
            \\  [5] Pre-Compaction Dump:     {s}{s}{s}
            \\  [6] Tool Output Limit:       {s}{s}{s} (trims large command/file logs)
            \\  [7] Thinking / Reasoning:    {s}{s:<16}{s} (low | medium | high | max)
            \\  [8] Output Verbosity:        {s}{s:<16}{s} (quiet | normal | full_transcript)
            \\  [9] Execution Sandbox:       {s}{s}{s}
            \\─────────────────────────────────────────────────────────────────────────────
            \\
        , .{
            tui.TUI.C_CYAN, tui.TUI.C_RESET,
            if (self.config.unbounded_autonomy) tui.TUI.C_AQUA else tui.TUI.C_ORANGE,
            if (self.config.unbounded_autonomy) "⚡ UNBOUNDED (Unlimited Autonomy)" else "Bounded Step Mode",
            tui.TUI.C_RESET,
            tui.TUI.C_WHITE, self.config.max_steps, tui.TUI.C_RESET,
            tui.TUI.C_AQUA, self.config.context_strategy.asString(), tui.TUI.C_RESET,
            tui.TUI.C_ORANGE, self.config.auto_compact_threshold_pct, tui.TUI.C_RESET,
            if (self.config.pre_compact_dump) tui.TUI.C_AQUA else tui.TUI.C_ORANGE,
            if (self.config.pre_compact_dump) "✔ Enabled (Auto-Dump Checkpoint)" else "✘ Disabled",
            tui.TUI.C_RESET,
            tui.TUI.C_WHITE, self.config.tool_output_limit.asString(), tui.TUI.C_RESET,
            tui.TUI.C_ORANGE, self.config.thinking_effort.asString(), tui.TUI.C_RESET,
            tui.TUI.C_AQUA, self.config.verbosity.asString(), tui.TUI.C_RESET,
            if (self.config.sandbox_enabled) tui.TUI.C_AQUA else tui.TUI.C_ORANGE,
            if (self.config.sandbox_enabled) "Enabled (Safe)" else "Disabled",
            tui.TUI.C_RESET,
        });
    }
};
