const std = @import("std");
const sys = @import("sys.zig");
const auth = @import("auth.zig");

pub const SYSTEM_PROMPT_WITH_TOOLS =
    "Your name is Ziggy (also known as ZigAgent). You are an ultra-fast, intelligent autonomous AI coding agent written in pure native Zig with live file, terminal, git, MCP, and skill execution capabilities.\\n" ++
    "When working on a task, thinking through architecture, or deciding on actions, ALWAYS begin your response with a <think>...</think> block containing your internal thoughts and step-by-step plan.\\n" ++
    "When you need to read or edit files, execute commands, or search the project, invoke a tool using this EXACT format:\\n" ++
    "<tool_call>\\n" ++
    "{\\\"name\\\": \\\"tool_name\\\", \\\"arguments\\\": {\\\"param\\\": \\\"value\\\"}}\\n" ++
    "</tool_call>\\n\\n" ++
    "Available Native & MCP Tools:\\n" ++
    "• read_file: {\\\"path\\\": \\\"path/to/file\\\"}\\n" ++
    "• write_file: {\\\"path\\\": \\\"path/to/file\\\", \\\"content\\\": \\\"file text\\\"}\\n" ++
    "• edit_file: {\\\"path\\\": \\\"path/to/file\\\", \\\"target\\\": \\\"exact substring to replace\\\", \\\"replacement\\\": \\\"new code\\\"}\\n" ++
    "• run_command: {\\\"command\\\": \\\"shell command\\\"}\\n" ++
    "• list_dir: {\\\"path\\\": \\\".\\\"}\\n" ++
    "• grep_search: {\\\"query\\\": \\\"pattern\\\", \\\"path\\\": \\\".\\\"}\\n" ++
    "• find_files: {\\\"pattern\\\": \\\"*.zig\\\", \\\"path\\\": \\\".\\\"}\\n" ++
    "• fetch_web: {\\\"url\\\": \\\"https://...\\\"}\\n" ++
    "• git_status: {}\\n" ++
    "• git_diff: {}\\n" ++
    "• git_log: {}\\n" ++
    "• git_commit: {\\\"message\\\": \\\"commit text\\\"}\\n\\n" ++
    "Always think in <think> tags, take tool actions in <tool_call> tags, and provide a clear final summary after actions are complete.";

pub const HttpClient = struct {
    pub fn queryInference(
        allocator: std.mem.Allocator,
        vault: *const auth.AuthVault,
        model: []const u8,
        prompt: []const u8,
        out_buf: []u8,
    ) usize {
        const groq_key = vault.getKey(.groq);
        const or_key = vault.getKey(.openrouter);

        if (groq_key.len > 0) {
            const res = queryGroq(allocator, groq_key, model, prompt, out_buf);
            if (res > 0) return res;
        }

        if (or_key.len > 0) {
            const res = queryOpenRouter(allocator, or_key, model, prompt, out_buf);
            if (res > 0) return res;
        }

        const fallback = "No active API keys found or inference failed. Run /keys or /login <provider> <key>.";
        const len = @min(fallback.len, out_buf.len);
        @memcpy(out_buf[0..len], fallback[0..len]);
        return len;
    }

    fn queryGroq(
        allocator: std.mem.Allocator,
        api_key: []const u8,
        model: []const u8,
        prompt: []const u8,
        out_buf: []u8,
    ) usize {
        const actual_model = if (std.mem.indexOf(u8, model, "120b") != null)
            "openai/gpt-oss-120b"
        else if (std.mem.indexOf(u8, model, "qwen") != null)
            "qwen/qwen3.8-27b"
        else
            "openai/gpt-oss-120b";

        return executeCurlInference(allocator, "https://api.groq.com/openai/v1/chat/completions", api_key, actual_model, prompt, out_buf);
    }

    fn queryOpenRouter(
        allocator: std.mem.Allocator,
        api_key: []const u8,
        model: []const u8,
        prompt: []const u8,
        out_buf: []u8,
    ) usize {
        return executeCurlInference(allocator, "https://openrouter.ai/api/v1/chat/completions", api_key, model, prompt, out_buf);
    }

    fn executeCurlInference(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        api_key: []const u8,
        model: []const u8,
        prompt: []const u8,
        out_buf: []u8,
    ) usize {
        _ = allocator;
        var escaped_buf: [16384]u8 = undefined;
        var esc_len: usize = 0;
        for (prompt) |ch| {
            if (esc_len >= escaped_buf.len - 4) break;
            if (ch == '"' or ch == '\\') {
                escaped_buf[esc_len] = '\\';
                esc_len += 1;
            }
            if (ch == '\n') {
                escaped_buf[esc_len] = '\\';
                escaped_buf[esc_len + 1] = 'n';
                esc_len += 2;
                continue;
            }
            escaped_buf[esc_len] = ch;
            esc_len += 1;
        }
        const clean_prompt = escaped_buf[0..esc_len];

        var cmd_buf: [32768]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "curl -s \"{s}\" -H \"Authorization: Bearer {s}\" -H \"Content-Type: application/json\" -d '{{\"model\": \"{s}\", \"messages\": [{{\"role\": \"system\", \"content\": \"{s}\"}}, {{\"role\": \"user\", \"content\": \"{s}\"}}]}}'",
            .{ endpoint, api_key, model, SYSTEM_PROMPT_WITH_TOOLS, clean_prompt },
        ) catch return 0;

        cmd_buf[cmd.len] = 0;
        const cmd_z: [*:0]const u8 = @ptrCast(cmd_buf[0..cmd.len]);
        const pipe = sys.Sys.popen(cmd_z, "r") orelse return 0;
        defer _ = sys.Sys.pclose(pipe);

        var resp_raw: [32768]u8 = undefined;
        var total_read: usize = 0;
        while (total_read < resp_raw.len - 1) {
            const dest_ptr: [*]u8 = @ptrCast(&resp_raw[total_read]);
            const r = sys.Sys.fread(dest_ptr, 1, resp_raw.len - 1 - total_read, pipe);
            if (r <= 0) break;
            total_read += r;
        }
        resp_raw[total_read] = 0;

        const raw_slice = resp_raw[0..total_read];
        if (std.mem.indexOf(u8, raw_slice, "\"content\":\"")) |start_idx| {
            const content_start = start_idx + 11;
            var content_end = content_start;
            var escaped = false;
            while (content_end < raw_slice.len) {
                const c = raw_slice[content_end];
                if (c == '\\') {
                    escaped = !escaped;
                } else if (c == '"' and !escaped) {
                    break;
                } else {
                    escaped = false;
                }
                content_end += 1;
            }

            const raw_content = raw_slice[content_start..content_end];
            var out_cursor: usize = 0;
            var i: usize = 0;
            while (i < raw_content.len and out_cursor < out_buf.len - 1) {
                if (raw_content[i] == '\\' and i + 1 < raw_content.len) {
                    if (raw_content[i + 1] == 'n') {
                        out_buf[out_cursor] = '\n';
                        out_cursor += 1;
                        i += 2;
                        continue;
                    } else if (raw_content[i + 1] == 't') {
                        out_buf[out_cursor] = '\t';
                        out_cursor += 1;
                        i += 2;
                        continue;
                    } else if (raw_content[i + 1] == '"') {
                        out_buf[out_cursor] = '"';
                        out_cursor += 1;
                        i += 2;
                        continue;
                    } else if (raw_content[i + 1] == '\\') {
                        out_buf[out_cursor] = '\\';
                        out_cursor += 1;
                        i += 2;
                        continue;
                    } else if (std.mem.startsWith(u8, raw_content[i..], "\\u003c")) {
                        out_buf[out_cursor] = '<';
                        out_cursor += 1;
                        i += 6;
                        continue;
                    } else if (std.mem.startsWith(u8, raw_content[i..], "\\u003e")) {
                        out_buf[out_cursor] = '>';
                        out_cursor += 1;
                        i += 6;
                        continue;
                    }
                }
                out_buf[out_cursor] = raw_content[i];
                out_cursor += 1;
                i += 1;
            }
            return out_cursor;
        }

        return 0;
    }
};
