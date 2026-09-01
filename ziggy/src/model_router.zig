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
            .frontier_reasoning => "Frontier Deep Reasoning (120B+)",
            .fast_coding => "Ultra-Fast LPU Coder (70B)",
            .stealth_expert => "Stealth Code Specialist (27B)",
            .fallback_light => "Lightweight High-Throughput Fallback",
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

    pub fn listModels(self: *const ModelRouter) void {
        std.debug.print("\n{s}=== INTELLIGENT MODEL ROUTING CASCADE ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        for (DEFAULT_ROUTING_CHAIN, 0..) |c, i| {
            const is_active = (i == self.active_idx);
            const badge = if (is_active) "\x1b[1;38;2;49;196;141m[ACTIVE]\x1b[0m" else "\x1b[38;2;139;157;175m[READY]\x1b[0m";
            std.debug.print("  {s} {d}. \x1b[1m{s:<32}\x1b[0m ({s}) - {d}k tokens\n", .{
                badge, i + 1, c.name, c.tier.asString(), c.context_window / 1024,
            });
        }
        std.debug.print("\n{s}Use /model <number> to manually select or let router auto-cascade on rate limits.{s}\n\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }
};
