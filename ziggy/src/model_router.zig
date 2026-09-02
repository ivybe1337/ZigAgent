const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const auth = @import("auth.zig");
const http = @import("http.zig");

pub const ModelTier = enum {
    frontier_reasoning,
    fast_coding,
    stealth_expert,
    fallback_light,

    pub fn asString(self: ModelTier) []const u8 {
        return switch (self) {
            .frontier_reasoning => "Frontier Deep Reasoning",
            .fast_coding => "Ultra-Fast LPU Coder",
            .stealth_expert => "Stealth Code Specialist",
            .fallback_light => "Lightweight High-Throughput",
        };
    }
};

pub const ModelCandidate = struct {
    id: []const u8,
    name: []const u8,
    tier: ModelTier,
    provider: auth.ProviderType,
    context_window: usize,
};

pub const DEFAULT_ROUTING_CHAIN = [_]ModelCandidate{
    .{ .id = "openai/gpt-oss-120b", .name = "GPT-OSS 120B (Frontier)", .tier = .frontier_reasoning, .provider = .openrouter, .context_window = 131072 },
    .{ .id = "qwen/qwen3.8-27b", .name = "Qwen 3.8 27B (Stealth)", .tier = .stealth_expert, .provider = .openrouter, .context_window = 131072 },
    .{ .id = "meta-llama/llama-3.3-70b-instruct", .name = "Llama 3.3 70B (Fast LPU)", .tier = .fast_coding, .provider = .groq, .context_window = 131072 },
    .{ .id = "anthropic/claude-3.7-sonnet", .name = "Claude 3.7 Sonnet (Hybrid)", .tier = .frontier_reasoning, .provider = .openrouter, .context_window = 200000 },
    .{ .id = "google/gemini-2.5-pro", .name = "Gemini 2.5 Pro (1M Context)", .tier = .frontier_reasoning, .provider = .gemini, .context_window = 1048576 },
    .{ .id = "deepseek/deepseek-r1", .name = "DeepSeek R1 (Reasoning)", .tier = .frontier_reasoning, .provider = .openrouter, .context_window = 65536 },
    .{ .id = "mistralai/codestral-2501", .name = "Codestral 2501 (Code Base)", .tier = .fast_coding, .provider = .openrouter, .context_window = 262144 },
    .{ .id = "ollama/local", .name = "Ollama Local Instance (0 ms)", .tier = .fallback_light, .provider = .ollama, .context_window = 32768 },
};

pub const ModelRouter = struct {
    allocator: std.mem.Allocator,
    active_idx: usize = 0,

    pub fn init(allocator: std.mem.Allocator) ModelRouter {
        return .{
            .allocator = allocator,
            .active_idx = 0,
        };
    }

    pub fn getActiveModel(self: *const ModelRouter) ModelCandidate {
        return DEFAULT_ROUTING_CHAIN[self.active_idx % DEFAULT_ROUTING_CHAIN.len];
    }

    pub fn selectModelInteractively(self: *ModelRouter, current_active: []const u8) ?[]const u8 {
        var selected: usize = 0;
        for (DEFAULT_ROUTING_CHAIN, 0..) |c, i| {
            if (std.mem.eql(u8, c.id, current_active)) {
                selected = i;
                break;
            }
        }

        while (true) {
            std.debug.print(
                \\
                \\{s}╭─────────────────────────────────────────────────────────────────────────────╮{s}
                \\{s}│                    ⚡ SELECT ACTIVE INFERENCE MODEL                         │{s}
                \\{s}├─────────────────────────────────────────────────────────────────────────────┤{s}
                \\{s}│  Type number [1-8] or press ENTER for highlighted • 'q' to cancel           │{s}
                \\{s}├─────────────────────────────────────────────────────────────────────────────┤{s}
                \\
            , .{
                tui.TUI.C_BORDER, tui.TUI.C_RESET,
                tui.TUI.C_CYAN, tui.TUI.C_RESET,
                tui.TUI.C_BORDER, tui.TUI.C_RESET,
                tui.TUI.C_MUTED, tui.TUI.C_RESET,
                tui.TUI.C_BORDER, tui.TUI.C_RESET,
            });

            for (DEFAULT_ROUTING_CHAIN, 0..) |c, i| {
                const is_sel = (i == selected);
                const prefix = if (is_sel) " ▶ " else "   ";
                const val_color = if (is_sel) "\x1b[1;38;2;49;196;141m" else "\x1b[38;2;240;246;252m";
                std.debug.print(
                    "{s}│{s} {s}\x1b[1;38;2;0;242;254m[{d}]\x1b[0m {s}{s:<30}\x1b[0m \x1b[38;2;139;157;175m({s})\x1b[0m {s}│{s}\n",
                    .{ tui.TUI.C_BORDER, tui.TUI.C_RESET, prefix, i + 1, val_color, c.name, c.tier.asString(), tui.TUI.C_BORDER, tui.TUI.C_RESET },
                );
            }

            std.debug.print(
                \\{s}╰─────────────────────────────────────────────────────────────────────────────╯{s}
                \\
            , .{ tui.TUI.C_BORDER, tui.TUI.C_RESET });

            const prompt_str = "\x1b[38;2;60;80;110m│ \x1b[1;38;2;0;242;254mSelect Model [1-8, or ENTER to select, q to exit]\x1b[0m ❯ ";
            _ = sys.Sys.write(1, prompt_str, prompt_str.len);

            var choice_buf: [64]u8 = undefined;
            var choice_len: usize = 0;
            while (choice_len < choice_buf.len - 1) {
                var ch: [1]u8 = undefined;
                const r = sys.Sys.read(0, &ch, 1);
                if (r <= 0) break;
                if (ch[0] == '\n' or ch[0] == '\r') break;
                choice_buf[choice_len] = ch[0];
                choice_len += 1;
            }
            choice_buf[choice_len] = 0;

            const input = std.mem.trim(u8, choice_buf[0..choice_len], " \t\r\n");
            if (std.mem.eql(u8, input, "q") or std.mem.eql(u8, input, "Q")) {
                return null;
            }

            if (input.len == 0) {
                self.active_idx = selected;
                return DEFAULT_ROUTING_CHAIN[selected].id;
            }

            if (input.len == 1) {
                const opt = input[0];
                if (opt >= '1' and opt <= '0' + @as(u8, @intCast(DEFAULT_ROUTING_CHAIN.len))) {
                    const idx: usize = @intCast(opt - '1');
                    self.active_idx = idx;
                    return DEFAULT_ROUTING_CHAIN[idx].id;
                }
            }
        }
    }

    /// Automatically execute inference with failover routing
    pub fn queryWithFailover(
        self: *ModelRouter,
        vault: *const auth.AuthVault,
        prompt: []const u8,
        out_buf: []u8,
    ) usize {
        var attempt: usize = 0;
        while (attempt < DEFAULT_ROUTING_CHAIN.len) : (attempt += 1) {
            const current_candidate = DEFAULT_ROUTING_CHAIN[(self.active_idx + attempt) % DEFAULT_ROUTING_CHAIN.len];
            const bytes = http.HttpClient.queryInference(self.allocator, vault, current_candidate.id, prompt, out_buf);
            
            if (bytes > 0 and !std.mem.startsWith(u8, out_buf[0..bytes], "No active API keys")) {
                if (attempt > 0) {
                    std.debug.print("\x1b[38;2;255;107;53m⚡ [ROUTER FAILOVER]:\x1b[0m Switched to fallback model: {s}\n", .{current_candidate.name});
                    self.active_idx = (self.active_idx + attempt) % DEFAULT_ROUTING_CHAIN.len;
                }
                return bytes;
            }
        }
        return 0;
    }
};
