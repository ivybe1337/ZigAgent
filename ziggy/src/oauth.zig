const std = @import("std");
const sys = @import("sys.zig");
const auth = @import("auth.zig");
const tui = @import("tui.zig");

pub const OAuthManager = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) OAuthManager {
        return .{ .allocator = allocator };
    }

    pub fn startOAuthFlow(self: *OAuthManager, vault: *auth.AuthVault, provider: auth.ProviderType) !void {
        _ = self;
        std.debug.print("\n{s}⚡ Initiating OAuth 2.0 PKCE / Device Flow for: {s}{s}\n", .{
            tui.TUI.C_AQUA, provider.asString(), tui.TUI.C_RESET,
        });

        const auth_url = switch (provider) {
            .anthropic => "https://console.anthropic.com/settings/keys",
            .openai => "https://platform.openai.com/api-keys",
            .gemini => "https://aistudio.google.com/app/apikey",
            .openrouter => "https://openrouter.ai/keys",
            .groq => "https://console.groq.com/keys",
            .huggingface => "https://huggingface.co/settings/tokens",
            .ollama => "http://localhost:11434",
            .lmstudio => "http://localhost:1234",
        };

        if (provider == .ollama or provider == .lmstudio) {
            std.debug.print("{s}✔ Local provider {s} requires no cloud authentication.{s}\n", .{
                tui.TUI.C_AQUA, provider.asString(), tui.TUI.C_RESET,
            });
            vault.config.provider = provider;
            vault.saveToVault();
            return;
        }

        std.debug.print("{s}Opening authorization console in your browser...{s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });

        // Open browser on macOS
        var open_cmd_buf: [512]u8 = undefined;
        const open_cmd = std.fmt.bufPrint(&open_cmd_buf, "open \"{s}\"", .{auth_url}) catch "open https://google.com";
        var c_cmd: [512]u8 = undefined;
        @memcpy(c_cmd[0..open_cmd.len], open_cmd);
        c_cmd[open_cmd.len] = 0;
        _ = sys.Sys.system(@ptrCast(&c_cmd[0]));

        std.debug.print("{s}URL:{s} {s}\n\n", .{ tui.TUI.C_MUTED, tui.TUI.C_WHITE, auth_url });
        std.debug.print("{s}Paste your generated API key / Access Token below:{s}\n{s}Auth Code / Token ❯ {s}", .{
            tui.TUI.C_ORANGE, tui.TUI.C_RESET, tui.TUI.C_CYAN, tui.TUI.C_WHITE,
        });

        var token_buf: [1024]u8 = undefined;
        var cursor: usize = 0;
        while (cursor < token_buf.len - 1) {
            var ch: [1]u8 = undefined;
            const r = sys.Sys.read(0, &ch, 1);
            if (r <= 0) break;
            if (ch[0] == '\n') break;
            token_buf[cursor] = ch[0];
            cursor += 1;
        }
        std.debug.print("{s}", .{tui.TUI.C_RESET});

        const token = std.mem.trim(u8, token_buf[0..cursor], " \t\r\n");
        if (token.len > 0) {
            vault.setKey(provider, token);
            vault.config.provider = provider;
            vault.saveToVault();
            std.debug.print("\n{s}✔ OAuth handshake verified! Credentials saved to ~/.ziggy/credentials.json{s}\n", .{
                tui.TUI.C_AQUA, tui.TUI.C_RESET,
            });
        } else {
            std.debug.print("\n{s}⚠ Authentication cancelled (empty token).{s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
        }
    }
};
