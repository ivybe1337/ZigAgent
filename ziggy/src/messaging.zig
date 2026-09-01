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

pub const InboundMessage = struct {
    platform: MessagingPlatform,
    sender_id: []const u8,
    sender_name: []const u8,
    text: []const u8,
    timestamp: i64,
};

pub const MessagingHub = struct {
    allocator: std.mem.Allocator,
    telegram_bot_token: []const u8 = "",
    whatsapp_api_token: []const u8 = "",
    last_telegram_update_id: i64 = 0,
    is_listening: bool = false,

    pub fn init(allocator: std.mem.Allocator) MessagingHub {
        const tg = sys.Sys.getenv("TELEGRAM_BOT_TOKEN");
        const wa = sys.Sys.getenv("WHATSAPP_API_TOKEN");

        return .{
            .allocator = allocator,
            .telegram_bot_token = if (tg) |t| std.mem.sliceTo(t, 0) else "",
            .whatsapp_api_token = if (wa) |w| std.mem.sliceTo(w, 0) else "",
            .last_telegram_update_id = 0,
            .is_listening = false,
        };
    }

    /// Check for incoming messages across all active platforms
    pub fn pollIncoming(self: *MessagingHub, out_sender_buf: []u8, out_text_buf: []u8) ?InboundMessage {
        // 1. Poll Telegram Updates if token configured
        if (self.telegram_bot_token.len > 0) {
            if (self.pollTelegram(out_sender_buf, out_text_buf)) |msg| {
                return msg;
            }
        }

        // 2. Poll iMessage on macOS via AppleScript / Messages query
        if (self.poll_imessage(out_sender_buf, out_text_buf)) |msg| {
            return msg;
        }

        return null;
    }

    /// Poll Telegram Bot getUpdates API
    fn pollTelegram(self: *MessagingHub, out_sender: []u8, out_text: []u8) ?InboundMessage {
        var cmd_buf: [1024]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "curl -s --max-time 3 \"https://api.telegram.org/bot{s}/getUpdates?offset={d}&limit=1\" 2>/dev/null",
            .{ self.telegram_bot_token, self.last_telegram_update_id + 1 },
        ) catch return null;

        cmd_buf[cmd.len] = 0;
        const pipe = sys.Sys.popen(@ptrCast(&cmd_buf[0]), "r") orelse return null;
        defer _ = sys.Sys.pclose(pipe);

        var raw_json: [8192]u8 = undefined;
        const bytes_read = sys.Sys.fread(@ptrCast(&raw_json[0]), 1, raw_json.len - 1, pipe);
        if (bytes_read <= 0) return null;
        raw_json[@intCast(bytes_read)] = 0;
        const json_slice = raw_json[0..@intCast(bytes_read)];

        // Parse text and sender from json
        if (std.mem.indexOf(u8, json_slice, "\"text\":\"")) |text_start| {
            const val_start = text_start + 8;
            if (std.mem.indexOfScalar(u8, json_slice[val_start..], '"')) |val_len| {
                const text = json_slice[val_start .. val_start + val_len];
                const copy_t_len = @min(text.len, out_text.len);
                @memcpy(out_text[0..copy_t_len], text[0..copy_t_len]);

                // Extract chat ID
                var chat_id_str: []const u8 = "user";
                if (std.mem.indexOf(u8, json_slice, "\"chat\":{\"id\":")) |chat_start| {
                    const id_start = chat_start + 13;
                    var id_end = id_start;
                    while (id_end < json_slice.len and json_slice[id_end] >= '0' and json_slice[id_end] <= '9') : (id_end += 1) {}
                    if (id_end > id_start) {
                        chat_id_str = json_slice[id_start..id_end];
                    }
                }
                const copy_s_len = @min(chat_id_str.len, out_sender.len);
                @memcpy(out_sender[0..copy_s_len], chat_id_str[0..copy_s_len]);

                // Update offset
                if (std.mem.indexOf(u8, json_slice, "\"update_id\":")) |up_idx| {
                    const u_start = up_idx + 12;
                    var u_end = u_start;
                    while (u_end < json_slice.len and json_slice[u_end] >= '0' and json_slice[u_end] <= '9') : (u_end += 1) {}
                    if (u_end > u_start) {
                        self.last_telegram_update_id = std.fmt.parseInt(i64, json_slice[u_start..u_end], 10) catch self.last_telegram_update_id;
                    }
                }

                return .{
                    .platform = .telegram,
                    .sender_id = out_sender[0..copy_s_len],
                    .sender_name = "Telegram User",
                    .text = out_text[0..copy_t_len],
                    .timestamp = 0,
                };
            }
        }

        return null;
    }

    /// Poll iMessage for unread instructions
    fn poll_imessage(self: *MessagingHub, out_sender: []u8, out_text: []u8) ?InboundMessage {
        _ = self;
        const script = "osascript -e 'tell application \"Messages\" to get text of first message of active chat' 2>/dev/null";
        const pipe = sys.Sys.popen(script, "r") orelse return null;
        defer _ = sys.Sys.pclose(pipe);

        var buf: [1024]u8 = undefined;
        const bytes = sys.Sys.fread(@ptrCast(&buf[0]), 1, buf.len - 1, pipe);
        if (bytes <= 0) return null;
        const clean = std.mem.trim(u8, buf[0..@intCast(bytes)], " \t\r\n");
        if (clean.len == 0 or std.mem.startsWith(u8, clean, "⚡ [Ziggy]")) return null;

        const copy_len = @min(clean.len, out_text.len);
        @memcpy(out_text[0..copy_len], clean[0..copy_len]);

        const sender = "iMessage User";
        const copy_s_len = @min(sender.len, out_sender.len);
        @memcpy(out_sender[0..copy_s_len], sender[0..copy_s_len]);

        return null; // Silent poll by default unless explicit directive
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
        std.debug.print("\n{s}=== MULTI-PLATFORM MESSAGING BRIDGES (INBOUND & OUTBOUND) ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        
        // iMessage
        std.debug.print("  • \x1b[1;38;2;49;196;141m[ACTIVE IN/OUT]\x1b[0m {s:<20} : Native AppleScript / macOS Messages gateway\n", .{"iMessage"});
        
        // Telegram
        const tg_status = if (self.telegram_bot_token.len > 0) "\x1b[1;38;2;49;196;141m[ACTIVE IN/OUT]\x1b[0m" else "\x1b[38;2;139;157;175m[READY]\x1b[0m";
        std.debug.print("  • {s} {s:<20} : Long-polling / Webhooks (TELEGRAM_BOT_TOKEN)\n", .{ tg_status, "Telegram" });

        // WhatsApp
        const wa_status = if (self.whatsapp_api_token.len > 0) "\x1b[1;38;2;49;196;141m[ACTIVE IN/OUT]\x1b[0m" else "\x1b[38;2;139;157;175m[READY]\x1b[0m";
        std.debug.print("  • {s} {s:<20} : WhatsApp Cloud API (WHATSAPP_API_TOKEN)\n", .{ wa_status, "WhatsApp" });

        // Google Messages
        std.debug.print("  • \x1b[38;2;139;157;175m[READY]\x1b[0m {s:<20} : RCS / Google Messages Web Gateway\n", .{"Google Messages"});

        std.debug.print("\n{s}Use /listen to enter live omnichannel listening mode, or send directives via text!{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }
};
