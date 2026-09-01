const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const MessagingPlatform = enum {
    imessage,
    telegram,
    whatsapp,
    google_messages,

    pub fn asString(self: MessagingPlatform) []const u8 {
        return switch (self) {
            .imessage => "Apple iMessage",
            .telegram => "Telegram Bot API",
            .whatsapp => "WhatsApp Cloud API",
            .google_messages => "Google Messages Bridge",
        };
    }
};

pub const MessagingHub = struct {
    allocator: std.mem.Allocator,
    telegram_bot_token: []const u8 = "",
    whatsapp_api_token: []const u8 = "",

    pub fn init(allocator: std.mem.Allocator) MessagingHub {
        const tg = sys.Sys.getenv("TELEGRAM_BOT_TOKEN");
        const wa = sys.Sys.getenv("WHATSAPP_API_TOKEN");

        return .{
            .allocator = allocator,
            .telegram_bot_token = if (tg) |t| std.mem.sliceTo(t, 0) else "",
            .whatsapp_api_token = if (wa) |w| std.mem.sliceTo(w, 0) else "",
        };
    }

    /// Send message via macOS native AppleScript to iMessage
    pub fn send_imessage(self: *MessagingHub, recipient: []const u8, message: []const u8) bool {
        _ = self;
        var script_buf: [4096]u8 = undefined;
        var esc_msg_buf: [2048]u8 = undefined;
        var esc_len: usize = 0;
        for (message) |c| {
            if (esc_len >= esc_msg_buf.len - 2) break;
            if (c == '"' or c == '\\') {
                esc_msg_buf[esc_len] = '\\';
                esc_len += 1;
            }
            esc_msg_buf[esc_len] = c;
            esc_len += 1;
        }

        const script = std.fmt.bufPrint(
            &script_buf,
            "osascript -e 'tell application \"Messages\" to send \"{s}\" to buddy \"{s}\"' 2>/dev/null",
            .{ esc_msg_buf[0..esc_len], recipient },
        ) catch return false;

        script_buf[script.len] = 0;
        const pipe = sys.Sys.popen(@ptrCast(&script_buf[0]), "r") orelse return false;
        defer _ = sys.Sys.pclose(pipe);
        return true;
    }

    /// Send message via Telegram Bot API
    pub fn send_telegram(self: *MessagingHub, chat_id: []const u8, message: []const u8) bool {
        if (self.telegram_bot_token.len == 0) return false;
        var cmd_buf: [4096]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "curl -s -X POST \"https://api.telegram.org/bot{s}/sendMessage\" -d \"chat_id={s}&text={s}\" > /dev/null",
            .{ self.telegram_bot_token, chat_id, message },
        ) catch return false;

        cmd_buf[cmd.len] = 0;
        const pipe = sys.Sys.popen(@ptrCast(&cmd_buf[0]), "r") orelse return false;
        defer _ = sys.Sys.pclose(pipe);
        return true;
    }

    /// Send message via WhatsApp Cloud API
    pub fn send_whatsapp(self: *MessagingHub, phone_number: []const u8, message: []const u8) bool {
        if (self.whatsapp_api_token.len == 0) return false;
        var cmd_buf: [4096]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "curl -s -X POST \"https://graph.facebook.com/v19.0/me/messages\" -H \"Authorization: Bearer {s}\" -H \"Content-Type: application/json\" -d '{{\"messaging_product\":\"whatsapp\",\"to\":\"{s}\",\"type\":\"text\",\"text\":{{\"body\":\"{s}\"}}}}' > /dev/null",
            .{ self.whatsapp_api_token, phone_number, message },
        ) catch return false;

        cmd_buf[cmd.len] = 0;
        const pipe = sys.Sys.popen(@ptrCast(&cmd_buf[0]), "r") orelse return false;
        defer _ = sys.Sys.pclose(pipe);
        return true;
    }

    pub fn listBridges(self: *const MessagingHub) void {
        std.debug.print("\n{s}=== MULTI-PLATFORM MESSAGING BRIDGES ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        
        // iMessage
        std.debug.print("  • \x1b[1;38;2;49;196;141m[ACTIVE]\x1b[0m {s:<24} : Native AppleScript / macOS Messages pipeline\n", .{"iMessage"});
        
        // Telegram
        const tg_status = if (self.telegram_bot_token.len > 0) "\x1b[1;38;2;49;196;141m[ACTIVE]\x1b[0m" else "\x1b[38;2;139;157;175m[READY]\x1b[0m";
        std.debug.print("  • {s} {s:<24} : Telegram Bot Webhook (TELEGRAM_BOT_TOKEN)\n", .{ tg_status, "Telegram" });

        // WhatsApp
        const wa_status = if (self.whatsapp_api_token.len > 0) "\x1b[1;38;2;49;196;141m[ACTIVE]\x1b[0m" else "\x1b[38;2;139;157;175m[READY]\x1b[0m";
        std.debug.print("  • {s} {s:<24} : WhatsApp Cloud API (WHATSAPP_API_TOKEN)\n", .{ wa_status, "WhatsApp" });

        // Google Messages
        std.debug.print("  • \x1b[38;2;139;157;175m[READY]\x1b[0m {s:<24} : RCS / Google Messages Web Gateway\n", .{"Google Messages"});

        std.debug.print("\n{s}Use /msg <imessage|telegram|whatsapp> <recipient> <text> to send direct messages.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }
};
