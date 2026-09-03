const std = @import("std");
const sys = @import("sys.zig");

pub const ProviderType = enum {
    openrouter,
    groq,
    anthropic,
    openai,
    gemini,
    huggingface,
    ollama,
    lmstudio,

    pub fn asString(self: ProviderType) []const u8 {
        return switch (self) {
            .openrouter => "OpenRouter",
            .groq => "Groq (Ultra-Fast)",
            .anthropic => "Anthropic (Claude)",
            .openai => "OpenAI / ChatGPT",
            .gemini => "Google Gemini",
            .huggingface => "Hugging Face",
            .ollama => "Ollama (Local)",
            .lmstudio => "LM Studio (Local)",
        };
    }

    pub fn parse(name: []const u8) ?ProviderType {
        if (std.ascii.eqlIgnoreCase(name, "openrouter") or std.ascii.eqlIgnoreCase(name, "openhands")) return .openrouter;
        if (std.ascii.eqlIgnoreCase(name, "groq")) return .groq;
        if (std.ascii.eqlIgnoreCase(name, "anthropic") or std.ascii.eqlIgnoreCase(name, "claude")) return .anthropic;
        if (std.ascii.eqlIgnoreCase(name, "openai") or std.ascii.eqlIgnoreCase(name, "chatgpt")) return .openai;
        if (std.ascii.eqlIgnoreCase(name, "gemini") or std.ascii.eqlIgnoreCase(name, "google")) return .gemini;
        if (std.ascii.eqlIgnoreCase(name, "huggingface") or std.ascii.eqlIgnoreCase(name, "hf")) return .huggingface;
        if (std.ascii.eqlIgnoreCase(name, "ollama")) return .ollama;
        if (std.ascii.eqlIgnoreCase(name, "lmstudio")) return .lmstudio;
        return null;
    }
};

pub const ProviderConfig = struct {
    provider: ProviderType = .openrouter,
    openrouter_key: [128]u8 = [_]u8{0} ** 128,
    groq_key: [128]u8 = [_]u8{0} ** 128,
    anthropic_key: [128]u8 = [_]u8{0} ** 128,
    openai_key: [128]u8 = [_]u8{0} ** 128,
    gemini_key: [128]u8 = [_]u8{0} ** 128,
    huggingface_key: [128]u8 = [_]u8{0} ** 128,
    custom_endpoint: [256]u8 = [_]u8{0} ** 256,
};

pub const AuthVault = struct {
    allocator: std.mem.Allocator,
    config: ProviderConfig,
    vault_path: [512]u8,
    vault_path_len: usize,

    pub fn init(allocator: std.mem.Allocator) AuthVault {
        var self = AuthVault{
            .allocator = allocator,
            .config = .{},
            .vault_path = [_]u8{0} ** 512,
            .vault_path_len = 0,
        };

        var home_path: [256]u8 = undefined;
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        @memcpy(home_path[0..home_len], home[0..home_len]);

        const path = std.fmt.bufPrint(&self.vault_path, "{s}/.ziggy", .{home_path[0..home_len]}) catch ".ziggy";
        _ = sys.makeDirAll(path);

        const full_file = std.fmt.bufPrint(&self.vault_path, "{s}/.ziggy/credentials.json", .{home_path[0..home_len]}) catch ".ziggy/credentials.json";
        self.vault_path_len = full_file.len;

        self.loadFromEnvironment();
        self.loadFromVault();

        return self;
    }

    pub fn loadFromEnvironment(self: *AuthVault) void {
        if (sys.Sys.getenv("OPENROUTER_API_KEY")) |val| self.setKey(.openrouter, std.mem.sliceTo(val, 0));
        if (sys.Sys.getenv("GROQ_API_KEY")) |val| self.setKey(.groq, std.mem.sliceTo(val, 0));
        if (sys.Sys.getenv("ANTHROPIC_API_KEY")) |val| self.setKey(.anthropic, std.mem.sliceTo(val, 0));
        if (sys.Sys.getenv("OPENAI_API_KEY")) |val| self.setKey(.openai, std.mem.sliceTo(val, 0));
        if (sys.Sys.getenv("GEMINI_API_KEY")) |val| self.setKey(.gemini, std.mem.sliceTo(val, 0));
        if (sys.Sys.getenv("HUGGINGFACE_API_KEY") orelse sys.Sys.getenv("HF_TOKEN")) |val| self.setKey(.huggingface, std.mem.sliceTo(val, 0));
    }

    pub fn setKey(self: *AuthVault, provider: ProviderType, key: []const u8) void {
        const dest = switch (provider) {
            .openrouter => &self.config.openrouter_key,
            .groq => &self.config.groq_key,
            .anthropic => &self.config.anthropic_key,
            .openai => &self.config.openai_key,
            .gemini => &self.config.gemini_key,
            .huggingface => &self.config.huggingface_key,
            .ollama, .lmstudio => return,
        };
        @memset(dest, 0);
        const len = @min(key.len, dest.len - 1);
        @memcpy(dest[0..len], key[0..len]);
    }

    pub fn getKey(self: *const AuthVault, provider: ProviderType) []const u8 {
        const src = switch (provider) {
            .openrouter => &self.config.openrouter_key,
            .groq => &self.config.groq_key,
            .anthropic => &self.config.anthropic_key,
            .openai => &self.config.openai_key,
            .gemini => &self.config.gemini_key,
            .huggingface => &self.config.huggingface_key,
            .ollama, .lmstudio => return "",
        };
        const len = std.mem.indexOfScalar(u8, src, 0) orelse src.len;
        return src[0..len];
    }

    pub fn hasKey(self: *const AuthVault, provider: ProviderType) bool {
        if (provider == .ollama or provider == .lmstudio) return true;
        return self.getKey(provider).len > 0;
    }

    pub fn saveToVault(self: *const AuthVault) void {
        var json_buf: [2048]u8 = undefined;
        const json = std.fmt.bufPrint(
            &json_buf,
            \\{{
            \\  "active_provider": "{s}",
            \\  "openrouter_key": "{s}",
            \\  "groq_key": "{s}",
            \\  "anthropic_key": "{s}",
            \\  "openai_key": "{s}",
            \\  "gemini_key": "{s}",
            \\  "huggingface_key": "{s}"
            \\}}
            \\
        , .{
            @tagName(self.config.provider),
            self.getKey(.openrouter),
            self.getKey(.groq),
            self.getKey(.anthropic),
            self.getKey(.openai),
            self.getKey(.gemini),
            self.getKey(.huggingface),
        }) catch return;

        const path = self.vault_path[0..self.vault_path_len];
        _ = sys.writeEntireFile(path, json);
    }

    pub fn loadFromVault(self: *AuthVault) void {
        const path = self.vault_path[0..self.vault_path_len];
        const content = sys.readEntireFile(self.allocator, path, 8192) orelse return;
        defer self.allocator.free(content);

        if (std.mem.indexOf(u8, content, "\"active_provider\": \"")) |idx| {
            const start = idx + "\"active_provider\": \"".len;
            if (std.mem.indexOfScalar(u8, content[start..], '"')) |end_idx| {
                const prov_str = content[start .. start + end_idx];
                if (ProviderType.parse(prov_str)) |p| {
                    self.config.provider = p;
                }
            }
        }

        self.extractKeyFromJson(content, "\"openrouter_key\": \"", .openrouter);
        self.extractKeyFromJson(content, "\"groq_key\": \"", .groq);
        self.extractKeyFromJson(content, "\"anthropic_key\": \"", .anthropic);
        self.extractKeyFromJson(content, "\"openai_key\": \"", .openai);
        self.extractKeyFromJson(content, "\"gemini_key\": \"", .gemini);
        self.extractKeyFromJson(content, "\"huggingface_key\": \"", .huggingface);
    }

    fn extractKeyFromJson(self: *AuthVault, json: []const u8, pattern: []const u8, provider: ProviderType) void {
        if (std.mem.indexOf(u8, json, pattern)) |idx| {
            const start = idx + pattern.len;
            if (std.mem.indexOfScalar(u8, json[start..], '"')) |end_idx| {
                const key = json[start .. start + end_idx];
                if (key.len > 0) self.setKey(provider, key);
            }
        }
    }

    pub fn maskKey(key: []const u8, buf: []u8) []const u8 {
        if (key.len == 0) return "Not set";
        if (key.len <= 8) return "********";
        var cursor: usize = 0;
        const prefix_len = @min(6, key.len);
        @memcpy(buf[cursor .. cursor + prefix_len], key[0..prefix_len]);
        cursor += prefix_len;

        const stars = "••••••••••••";
        @memcpy(buf[cursor .. cursor + stars.len], stars);
        cursor += stars.len;

        const suffix_len = @min(4, key.len);
        const start_suffix = key.len - suffix_len;
        @memcpy(buf[cursor .. cursor + suffix_len], key[start_suffix..]);
        cursor += suffix_len;

        return buf[0..cursor];
    }
};
