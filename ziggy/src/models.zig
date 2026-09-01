const std = @import("std");
const auth = @import("auth.zig");
const tui = @import("tui.zig");

pub const ModelSpec = struct {
    id: []const u8,
    name: []const u8,
    provider: auth.ProviderType,
    context_window_k: u32,
    supports_reasoning: bool,
    is_free: bool,
    description: []const u8,
};

pub const AVAILABLE_MODELS = [_]ModelSpec{
    // Live Free & Stealth Frontier Models (Fetched directly from OpenRouter)
    .{
        .id = "nvidia/nemotron-3-ultra-550b-a55b:free",
        .name = "NVIDIA Nemotron 3 Ultra 550B [FREE]",
        .provider = .openrouter,
        .context_window_k = 1000,
        .supports_reasoning = true,
        .is_free = true,
        .description = "NVIDIA 550B MoE frontier reasoning & agent orchestration (1M ctx)",
    },
    .{
        .id = "poolside/laguna-s-2.1:free",
        .name = "Poolside Laguna S 2.1 Coding Agent [FREE]",
        .provider = .openrouter,
        .context_window_k = 262,
        .supports_reasoning = true,
        .is_free = true,
        .description = "Poolside 118B elite autonomous coding & refactoring specialist",
    },
    .{
        .id = "thinkingmachines/inkling:free",
        .name = "Thinking Machines Inkling 975B [FREE]",
        .provider = .openrouter,
        .context_window_k = 1048,
        .supports_reasoning = true,
        .is_free = true,
        .description = "975B parameter multimodal frontier model with 1M token context",
    },
    .{
        .id = "cohere/north-mini-code:free",
        .name = "Cohere North Mini Code [FREE]",
        .provider = .openrouter,
        .context_window_k = 256,
        .supports_reasoning = true,
        .is_free = true,
        .description = "Cohere debut agentic coding MoE architecture",
    },
    .{
        .id = "z-ai/glm-5.2:free",
        .name = "Z.ai GLM 5.2 Reasoning [FREE]",
        .provider = .openrouter,
        .context_window_k = 256,
        .supports_reasoning = true,
        .is_free = true,
        .description = "Large-scale reasoning for long-horizon agent workflows",
    },
    .{
        .id = "minimax/minimax-m3:free",
        .name = "MiniMax M3 Multimodal [FREE]",
        .provider = .openrouter,
        .context_window_k = 1048,
        .supports_reasoning = true,
        .is_free = true,
        .description = "1M token multimodal foundation model",
    },
    .{
        .id = "google/gemma-4-31b-it:free",
        .name = "Google Gemma 4 31B Instruct [FREE]",
        .provider = .openrouter,
        .context_window_k = 262,
        .supports_reasoning = false,
        .is_free = true,
        .description = "Google DeepMind dense multimodal instruction model",
    },
    .{
        .id = "openrouter/free",
        .name = "OpenRouter Auto-Free Smart Gateway",
        .provider = .openrouter,
        .context_window_k = 200,
        .supports_reasoning = true,
        .is_free = true,
        .description = "Intelligently routes across all active live free models",
    },
};

pub fn renderModelPreviewList(active_model_id: []const u8) void {
    std.debug.print(
        \\
        \\{s}=== ZIGAGENT LIVE STEALTH & FREE FRONTIER MODEL REGISTRY ==={s}
        \\{s}ID                                                PROVIDER       TIER    CONTEXT   REASONING   NAME{s}
        \\─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
        \\
    , .{ tui.TUI.C_CYAN, tui.TUI.C_RESET, tui.TUI.C_MUTED, tui.TUI.C_RESET });

    for (AVAILABLE_MODELS) |m| {
        const is_active = std.mem.eql(u8, m.id, active_model_id);
        const reason_badge = if (m.supports_reasoning) "✔ [THINK] " else "  [DIRECT]";
        const tier_badge = if (m.is_free) "⭐ FREE" else "  PAID";

        const prov_str = m.provider.asString();
        const prov_short = if (prov_str.len > 14) prov_str[0..14] else prov_str;

        std.debug.print("{s}{s:<48} {s:<14} {s}   {d:>4}k    {s}  {s}\n", .{
            if (is_active) tui.TUI.C_AQUA else tui.TUI.C_WHITE,
            m.id,
            prov_short,
            tier_badge,
            m.context_window_k,
            reason_badge,
            m.name,
        });
    }

    std.debug.print(
        \\
        \\{s}Usage: Type {s}/model <model_id>{s} to activate any free model.{s}
        \\
    , .{ tui.TUI.C_MUTED, tui.TUI.C_ORANGE, tui.TUI.C_MUTED, tui.TUI.C_RESET });
}
