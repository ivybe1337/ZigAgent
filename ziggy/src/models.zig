const std = @import("std");
const sys = @import("sys.zig");
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

pub const ALL_MODELS = [_]ModelSpec{
    // === OpenRouter Frontier Reasoning ===
    .{
        .id = "openai/gpt-oss-120b",
        .name = "OpenAI GPT-OSS 120B",
        .provider = .openrouter,
        .context_window_k = 131,
        .supports_reasoning = true,
        .is_free = false,
        .description = "Frontier open-weights 120B reasoning model with native tool dispatch",
    },
    .{
        .id = "anthropic/claude-3.7-sonnet",
        .name = "Anthropic Claude 3.7 Sonnet",
        .provider = .anthropic,
        .context_window_k = 200,
        .supports_reasoning = true,
        .is_free = false,
        .description = "State-of-the-art hybrid reasoning & coding frontier architecture",
    },
    .{
        .id = "anthropic/claude-3.5-sonnet",
        .name = "Anthropic Claude 3.5 Sonnet",
        .provider = .anthropic,
        .context_window_k = 200,
        .supports_reasoning = false,
        .is_free = false,
        .description = "Industry standard benchmark leader for high-velocity software engineering",
    },
    .{
        .id = "deepseek/deepseek-r1",
        .name = "DeepSeek R1 (Reasoning)",
        .provider = .openrouter,
        .context_window_k = 65,
        .supports_reasoning = true,
        .is_free = false,
        .description = "Open frontier reasoning model with mathematical chain-of-thought",
    },
    .{
        .id = "deepseek/deepseek-chat",
        .name = "DeepSeek V3 (671B MoE)",
        .provider = .openrouter,
        .context_window_k = 65,
        .supports_reasoning = false,
        .is_free = false,
        .description = "Ultra-efficient 671B Mixture-of-Experts with 37B active parameters",
    },
    .{
        .id = "google/gemini-2.5-pro",
        .name = "Google Gemini 2.5 Pro",
        .provider = .gemini,
        .context_window_k = 1048,
        .supports_reasoning = true,
        .is_free = false,
        .description = "1M+ token context window with deep multi-pass reasoning",
    },
    .{
        .id = "qwen/qwen3.8-27b",
        .name = "Qwen 3.8 27B Stealth",
        .provider = .openrouter,
        .context_window_k = 131,
        .supports_reasoning = true,
        .is_free = false,
        .description = "Stealth compact reasoning specialist with superior code synthesis",
    },
    .{
        .id = "mistralai/codestral-2501",
        .name = "Mistral Codestral 2501",
        .provider = .openrouter,
        .context_window_k = 262,
        .supports_reasoning = false,
        .is_free = false,
        .description = "Specialized coding foundation model with 256k context window",
    },
    .{
        .id = "meta-llama/llama-3.3-70b-instruct",
        .name = "Meta Llama 3.3 70B Instruct",
        .provider = .groq,
        .context_window_k = 131,
        .supports_reasoning = false,
        .is_free = false,
        .description = "Fast, versatile open-weights powerhouse for multi-turn agentics",
    },

    // === OpenRouter Free Tier Models ===
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
        .name = "Poolside Laguna S 2.1 Coding [FREE]",
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

    // === Groq Ultra-Fast LPU Models ===
    .{
        .id = "groq/llama-3.3-70b-versatile",
        .name = "Groq Llama 3.3 70B (@300 tps)",
        .provider = .groq,
        .context_window_k = 128,
        .supports_reasoning = false,
        .is_free = false,
        .description = "Sub-100ms first-token latency on Groq LPU Tensor Streaming Processor",
    },
    .{
        .id = "groq/deepseek-r1-distill-llama-70b",
        .name = "Groq DeepSeek R1 70B (@280 tps)",
        .provider = .groq,
        .context_window_k = 128,
        .supports_reasoning = true,
        .is_free = false,
        .description = "DeepSeek R1 reasoning capability running at ultra-fast Groq LPU speeds",
    },

    // === Local Offline Engines ===
    .{
        .id = "ollama/qwen2.5-coder:32b",
        .name = "Ollama Qwen 2.5 Coder 32B (Local)",
        .provider = .ollama,
        .context_window_k = 32,
        .supports_reasoning = false,
        .is_free = true,
        .description = "Local offline Ollama instance with zero external network dependency",
    },
    .{
        .id = "lmstudio/local-model",
        .name = "LM Studio Local Instance",
        .provider = .lmstudio,
        .context_window_k = 32,
        .supports_reasoning = false,
        .is_free = true,
        .description = "Local developer environment model server on localhost:1234",
    },
};

pub const ModelBrowser = struct {
    /// Full OpenRouter-Style Interactive Scrollable Model Picker
    pub fn runInteractivePicker(allocator: std.mem.Allocator, current_model: []const u8) ?[]const u8 {
        _ = allocator;
        var selected_idx: usize = 0;
        for (ALL_MODELS, 0..) |m, i| {
            if (std.mem.eql(u8, m.id, current_model)) {
                selected_idx = i;
                break;
            }
        }

        var term_orig: sys.Termios = undefined;
        if (sys.Sys.tcgetattr(0, &term_orig) != 0) {
            return fallbackSelector(current_model);
        }

        var term_raw = term_orig;
        term_raw.c_lflag &= ~@as(c_ulong, 0x00000002 | 0x00000008); // ~ICANON, ~ECHO
        term_raw.c_cc[16] = 1; // VMIN = 1
        term_raw.c_cc[17] = 0; // VTIME = 0
        _ = sys.Sys.tcsetattr(0, 0, &term_raw);
        defer _ = sys.Sys.tcsetattr(0, 0, &term_orig);

        const page_size: usize = 10;
        var view_offset: usize = 0;

        while (true) {
            // Keep selected index in view
            if (selected_idx < view_offset) {
                view_offset = selected_idx;
            } else if (selected_idx >= view_offset + page_size) {
                view_offset = selected_idx - page_size + 1;
            }

            renderScreen(selected_idx, view_offset, page_size);

            var ch: [8]u8 = undefined;
            const r = sys.Sys.read(0, @ptrCast(&ch), 8);
            if (r <= 0) break;

            // 'q', 'Q', or ESC
            if (r == 1 and (ch[0] == 'q' or ch[0] == 'Q' or ch[0] == 27)) {
                break;
            }

            // ENTER -> Choose Model!
            if (ch[0] == '\n' or ch[0] == '\r') {
                _ = sys.Sys.write(1, "\x1b[2J\x1b[H", 7);
                return ALL_MODELS[selected_idx].id;
            }

            // Arrow UP (CSI [ A or SS3 O A or 'k')
            if ((r >= 3 and ch[0] == 27 and (ch[1] == '[' or ch[1] == 'O') and ch[2] == 'A') or ch[0] == 'k' or ch[0] == 'K') {
                if (selected_idx > 0) selected_idx -= 1 else selected_idx = ALL_MODELS.len - 1;
                continue;
            }

            // Arrow DOWN (CSI [ B or SS3 O B or 'j')
            if ((r >= 3 and ch[0] == 27 and (ch[1] == '[' or ch[1] == 'O') and ch[2] == 'B') or ch[0] == 'j' or ch[0] == 'J') {
                if (selected_idx < ALL_MODELS.len - 1) selected_idx += 1 else selected_idx = 0;
                continue;
            }

            // Page UP / Home
            if (r >= 4 and ch[0] == 27 and ch[1] == '[' and ch[2] == '5' and ch[3] == '~') {
                if (selected_idx > page_size) selected_idx -= page_size else selected_idx = 0;
                continue;
            }

            // Page DOWN / End
            if (r >= 4 and ch[0] == 27 and ch[1] == '[' and ch[2] == '6' and ch[3] == '~') {
                if (selected_idx + page_size < ALL_MODELS.len) selected_idx += page_size else selected_idx = ALL_MODELS.len - 1;
                continue;
            }
        }

        _ = sys.Sys.write(1, "\x1b[2J\x1b[H", 7);
        return null;
    }

    fn renderScreen(selected: usize, offset: usize, page_size: usize) void {
        var buf: [8192]u8 = undefined;
        var cursor: usize = 0;

        const hdr = std.fmt.bufPrint(
            buf[cursor..],
            \\{s}
            \\{s}╭─────────────────────────────────────────────────────────────────────────────────────────────╮{s}
            \\{s}│                     ⚡ OPENROUTER & FRONTIER MODEL SELECTION BROWSER                       │{s}
            \\{s}├─────────────────────────────────────────────────────────────────────────────────────────────┤{s}
            \\{s}│  [↑/↓/j/k] Scroll  •  [ENTER] Select & Activate  •  [ESC/q] Cancel                         │{s}
            \\{s}├─────────────────────────────────────────────────────────────────────────────────────────────┤{s}
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

        const end_idx = @min(offset + page_size, ALL_MODELS.len);
        for (ALL_MODELS[offset..end_idx], offset..) |m, idx| {
            const is_sel = (idx == selected);
            const prefix = if (is_sel) " ▶ " else "   ";
            const row_bg = if (is_sel) "\x1b[48;2;25;40;65m\x1b[1;38;2;83;182;255m" else "\x1b[38;2;220;226;235m";
            const badge = if (m.is_free) "\x1b[1;38;2;49;196;141m[FREE]\x1b[0m" else "\x1b[38;2;255;154;60m[PAID]\x1b[0m";
            const reason = if (m.supports_reasoning) "🧠 REASON" else "⚡ FAST  ";

            const row = std.fmt.bufPrint(
                buf[cursor..],
                "{s}│{s}{s}{s}{s:<40}\x1b[0m │ {s:<10} │ {s} │ {d:>4}k ctx │ {s} {s}│{s}\n",
                .{
                    tui.TUI.C_BORDER, tui.TUI.C_RESET,
                    row_bg, prefix, m.id,
                    m.provider.asString(),
                    badge,
                    m.context_window_k,
                    reason,
                    tui.TUI.C_BORDER, tui.TUI.C_RESET,
                },
            ) catch break;
            cursor += row.len;
        }

        // Fill remaining page lines if any
        if (end_idx - offset < page_size) {
            for (0..(page_size - (end_idx - offset))) |_| {
                const empty_row = std.fmt.bufPrint(
                    buf[cursor..],
                    "{s}│                                                                                             │{s}\n",
                    .{ tui.TUI.C_BORDER, tui.TUI.C_RESET },
                ) catch break;
                cursor += empty_row.len;
            }
        }

        // Detail Inspector Panel for Highlighted Model
        const sel_m = ALL_MODELS[selected];
        const footer = std.fmt.bufPrint(
            buf[cursor..],
            \\{s}├─────────────────────────────────────────────────────────────────────────────────────────────┤{s}
            \\{s}│  MODEL DETAILS [{d}/{d}]:                                                                     │{s}
            \\{s}│  \x1b[1;38;2;0;242;254m{s:<42}\x1b[0;38;2;139;157;175m Provider: \x1b[1;38;2;240;246;252m{s:<16}\x1b[0;38;2;139;157;175m Context: \x1b[1;38;2;49;196;141m{d}k tokens\x1b[0m{s}│{s}
            \\{s}│  \x1b[38;2;200;210;225m{s:<89}\x1b[0m{s}│{s}
            \\{s}╰─────────────────────────────────────────────────────────────────────────────────────────────╯{s}
            \\
        , .{
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
            tui.TUI.C_MUTED, selected + 1, ALL_MODELS.len, tui.TUI.C_RESET,
            tui.TUI.C_BORDER, sel_m.name, sel_m.provider.asString(), sel_m.context_window_k, tui.TUI.C_BORDER, tui.TUI.C_RESET,
            tui.TUI.C_BORDER, sel_m.description, tui.TUI.C_BORDER, tui.TUI.C_RESET,
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
        }) catch return;
        cursor += footer.len;

        _ = sys.Sys.write(1, @ptrCast(&buf), cursor);
    }

    fn fallbackSelector(current_model: []const u8) ?[]const u8 {
        _ = current_model;
        std.debug.print("\n=== OPENROUTER MODEL LIST ===\n", .{});
        for (ALL_MODELS, 0..) |m, i| {
            std.debug.print("  [{d}] {s} ({s})\n", .{ i + 1, m.id, m.name });
        }
        std.debug.print("Enter number [1-{d}]: ", .{ALL_MODELS.len});
        var buf: [32]u8 = undefined;
        const r = sys.Sys.read(0, &buf, 32);
        if (r <= 0) return null;
        const input = std.mem.trim(u8, buf[0..@intCast(r)], " \t\r\n");
        const idx = std.fmt.parseInt(usize, input, 10) catch return null;
        if (idx >= 1 and idx <= ALL_MODELS.len) {
            return ALL_MODELS[idx - 1].id;
        }
        return null;
    }
};
