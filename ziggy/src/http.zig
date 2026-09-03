const std = @import("std");
const sys = @import("sys.zig");
const auth = @import("auth.zig");

pub const SYSTEM_PROMPT_WITH_TOOLS =
    "Your name is Ziggy (also known as ZigAgent). You are an ultra-fast, intelligent autonomous AI coding agent written in pure native Zig with live file, terminal, git, MCP, and skill execution capabilities.\n" ++
    "When working on a task, thinking through architecture, or deciding on actions, ALWAYS begin your response with a <think>...</think> block containing your internal thoughts and step-by-step plan.\n" ++
    "When you need to read or edit files, execute commands, or search the project, invoke a tool using this EXACT format:\n" ++
    "<tool_call>\n" ++
    "{\"name\": \"tool_name\", \"arguments\": {\"param\": \"value\"}}\n" ++
    "</tool_call>\n\n" ++
    "Available Native & MCP Tools:\n" ++
    "• read_file: {\"path\": \"path/to/file\"}\n" ++
    "• write_file: {\"path\": \"path/to/file\", \"content\": \"file text\"}\n" ++
    "• edit_file: {\"path\": \"path/to/file\", \"target\": \"exact substring to replace\", \"replacement\": \"new code\"}\n" ++
    "• run_command: {\"command\": \"shell command\"}\n" ++
    "• list_dir: {\"path\": \".\"}\n" ++
    "• grep_search: {\"query\": \"pattern\", \"path\": \".\"}\n" ++
    "• find_files: {\"pattern\": \"*.zig\", \"path\": \".\"}\n" ++
    "• fetch_web: {\"url\": \"https://...\"}\n" ++
    "• git_status: {}\n" ++
    "• git_diff: {}\n" ++
    "• git_log: {}\n" ++
    "• git_commit: {\"message\": \"commit text\"}\n\n" ++
    "Always think in <think> tags, take tool actions in <tool_call> tags, and provide a clear final summary after actions are complete.";

pub const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
};

pub const UsageStats = struct {
    prompt_tokens: u32 = 0,
    completion_tokens: u32 = 0,
    total_tokens: u32 = 0,
};

pub var last_usage: UsageStats = .{};
pub var session_total_tokens: u64 = 0;

pub fn estimateTokens(text: []const u8) u32 {
    return estimateTokensFromBytes(text.len);
}

pub fn estimateTokensFromBytes(byte_len: usize) u32 {
    if (byte_len == 0) return 0;
    // Standard BPE estimation: ~3.8 chars per token for code/English
    return @intCast((byte_len * 10) / 38);
}

pub const HttpClient = struct {
    /// Single-prompt wrapper for compatibility
    pub fn queryInference(
        allocator: std.mem.Allocator,
        vault: *const auth.AuthVault,
        model: []const u8,
        prompt: []const u8,
        out_buf: []u8,
    ) usize {
        const msgs = [_]ChatMessage{
            .{ .role = "user", .content = prompt },
        };
        return queryInferenceMessages(allocator, vault, model, &msgs, out_buf);
    }

    /// Primary multi-turn inference pipeline with disk-buffered payload
    pub fn queryInferenceMessages(
        allocator: std.mem.Allocator,
        vault: *const auth.AuthVault,
        model: []const u8,
        messages: []const ChatMessage,
        out_buf: []u8,
    ) usize {
        _ = allocator;
        const or_key = vault.getKey(.openrouter);
        const groq_key = vault.getKey(.groq);

        // 1. If model specifies local Ollama/LMStudio
        if (std.mem.startsWith(u8, model, "ollama/") or std.mem.startsWith(u8, model, "lmstudio/")) {
            const actual_model = if (std.mem.indexOfScalar(u8, model, '/')) |slash_idx|
                model[slash_idx + 1 ..]
            else
                model;
            return executeCurlWithDiskPayload(
                "http://localhost:11434/v1/chat/completions",
                "ollama",
                actual_model,
                SYSTEM_PROMPT_WITH_TOOLS,
                messages,
                out_buf,
                false,
            );
        }

        // 2. OpenRouter is PRIMARY (User choice: "i do not use groq i use openrouter.")
        if (or_key.len > 0 and (vault.config.provider == .openrouter or !std.mem.startsWith(u8, model, "groq/"))) {
            const res = executeCurlWithDiskPayload(
                "https://openrouter.ai/api/v1/chat/completions",
                or_key,
                model,
                SYSTEM_PROMPT_WITH_TOOLS,
                messages,
                out_buf,
                true,
            );
            if (res > 0) return res;
        }

        // 3. Groq (only if explicitly requested via groq/ prefix or active provider)
        if (groq_key.len > 0 and (std.mem.startsWith(u8, model, "groq/") or vault.config.provider == .groq)) {
            const actual_model = if (std.mem.startsWith(u8, model, "groq/"))
                model[5..]
            else
                "llama-3.3-70b-versatile";
            const res = executeCurlWithDiskPayload(
                "https://api.groq.com/openai/v1/chat/completions",
                groq_key,
                actual_model,
                SYSTEM_PROMPT_WITH_TOOLS,
                messages,
                out_buf,
                false,
            );
            if (res > 0) return res;
        }

        // 4. Fallback if OpenRouter failed or no key set
        if (or_key.len > 0) {
            const res = executeCurlWithDiskPayload(
                "https://openrouter.ai/api/v1/chat/completions",
                or_key,
                model,
                SYSTEM_PROMPT_WITH_TOOLS,
                messages,
                out_buf,
                true,
            );
            if (res > 0) return res;
        }

        const fallback = "No active API keys found or neural inference failed. Run /keys to check your credentials.";
        const len = @min(fallback.len, out_buf.len);
        @memcpy(out_buf[0..len], fallback[0..len]);
        return len;
    }

    fn writeEscapedJson(fd: c_int, text: []const u8) void {
        var chunk_buf: [1024]u8 = undefined;
        var chunk_len: usize = 0;

        for (text) |b| {
            switch (b) {
                '"' => {
                    if (chunk_len + 2 > chunk_buf.len) {
                        _ = sys.Sys.write(fd, @ptrCast(&chunk_buf), chunk_len);
                        chunk_len = 0;
                    }
                    chunk_buf[chunk_len] = '\\';
                    chunk_buf[chunk_len + 1] = '"';
                    chunk_len += 2;
                },
                '\\' => {
                    if (chunk_len + 2 > chunk_buf.len) {
                        _ = sys.Sys.write(fd, @ptrCast(&chunk_buf), chunk_len);
                        chunk_len = 0;
                    }
                    chunk_buf[chunk_len] = '\\';
                    chunk_buf[chunk_len + 1] = '\\';
                    chunk_len += 2;
                },
                '\n' => {
                    if (chunk_len + 2 > chunk_buf.len) {
                        _ = sys.Sys.write(fd, @ptrCast(&chunk_buf), chunk_len);
                        chunk_len = 0;
                    }
                    chunk_buf[chunk_len] = '\\';
                    chunk_buf[chunk_len + 1] = 'n';
                    chunk_len += 2;
                },
                '\r' => {
                    if (chunk_len + 2 > chunk_buf.len) {
                        _ = sys.Sys.write(fd, @ptrCast(&chunk_buf), chunk_len);
                        chunk_len = 0;
                    }
                    chunk_buf[chunk_len] = '\\';
                    chunk_buf[chunk_len + 1] = 'r';
                    chunk_len += 2;
                },
                '\t' => {
                    if (chunk_len + 2 > chunk_buf.len) {
                        _ = sys.Sys.write(fd, @ptrCast(&chunk_buf), chunk_len);
                        chunk_len = 0;
                    }
                    chunk_buf[chunk_len] = '\\';
                    chunk_buf[chunk_len + 1] = 't';
                    chunk_len += 2;
                },
                else => {
                    if (b < 0x20) continue;
                    if (chunk_len + 1 > chunk_buf.len) {
                        _ = sys.Sys.write(fd, @ptrCast(&chunk_buf), chunk_len);
                        chunk_len = 0;
                    }
                    chunk_buf[chunk_len] = b;
                    chunk_len += 1;
                },
            }
        }
        if (chunk_len > 0) {
            _ = sys.Sys.write(fd, @ptrCast(&chunk_buf), chunk_len);
        }
    }

    fn executeCurlWithDiskPayload(
        endpoint: []const u8,
        api_key: []const u8,
        model: []const u8,
        system_prompt: []const u8,
        messages: []const ChatMessage,
        out_buf: []u8,
        is_openrouter: bool,
    ) usize {
        const req_file = "/tmp/ziggy_inference_req.json";
        const fd = sys.Sys.open(req_file, sys.O_WRONLY | sys.O_CREAT | sys.O_TRUNC, @as(c_uint, 0o644));
        if (fd < 0) return 0;

        // Construct complete OpenAI/OpenRouter compatible chat payload
        const p1 = "{\"model\": \"";
        _ = sys.Sys.write(fd, p1.ptr, p1.len);
        writeEscapedJson(fd, model);

        const p2 = "\", \"messages\": [{\"role\": \"system\", \"content\": \"";
        _ = sys.Sys.write(fd, p2.ptr, p2.len);
        writeEscapedJson(fd, system_prompt);
        const p3 = "\"}";
        _ = sys.Sys.write(fd, p3.ptr, p3.len);

        for (messages) |msg| {
            const m1 = ", {\"role\": \"";
            _ = sys.Sys.write(fd, m1.ptr, m1.len);
            writeEscapedJson(fd, msg.role);
            const m2 = "\", \"content\": \"";
            _ = sys.Sys.write(fd, m2.ptr, m2.len);
            writeEscapedJson(fd, msg.content);
            const m3 = "\"}";
            _ = sys.Sys.write(fd, m3.ptr, m3.len);
        }

        const p4 = "]}";
        _ = sys.Sys.write(fd, p4.ptr, p4.len);
        _ = sys.Sys.close(fd);

        // Execute curl with -d @/tmp/ziggy_inference_req.json (Zero shell escaping issues!)
        var cmd_buf: [2048]u8 = undefined;
        const cmd = if (is_openrouter)
            std.fmt.bufPrint(
                &cmd_buf,
                "curl -s --compressed -N \"{s}\" -H \"Authorization: Bearer {s}\" -H \"Content-Type: application/json\" -H \"HTTP-Referer: https://github.com/ivybe1337/ZigAgent\" -H \"X-Title: ZigAgent\" -d @{s}",
                .{ endpoint, api_key, req_file },
            ) catch return 0
        else
            std.fmt.bufPrint(
                &cmd_buf,
                "curl -s --compressed -N \"{s}\" -H \"Authorization: Bearer {s}\" -H \"Content-Type: application/json\" -d @{s}",
                .{ endpoint, api_key, req_file },
            ) catch return 0;

        cmd_buf[cmd.len] = 0;
        const cmd_z: [*:0]const u8 = @ptrCast(cmd_buf[0..cmd.len]);
        const pipe = sys.Sys.popen(cmd_z, "r") orelse {
            _ = sys.Sys.unlink(req_file);
            return 0;
        };
        defer {
            _ = sys.Sys.pclose(pipe);
            _ = sys.Sys.unlink(req_file);
        }

        var resp_raw: [131072]u8 = undefined;
        var total_read: usize = 0;
        while (total_read < resp_raw.len - 1) {
            const dest_ptr: [*]u8 = @ptrCast(&resp_raw[total_read]);
            const r = sys.Sys.fread(dest_ptr, 1, resp_raw.len - 1 - total_read, pipe);
            if (r <= 0) break;
            total_read += r;
        }
        resp_raw[total_read] = 0;

        const raw_slice = resp_raw[0..total_read];
        var out_cursor: usize = 0;

        // Extract real API usage tokens ("prompt_tokens": ..., "completion_tokens": ..., "total_tokens": ...)
        if (std.mem.indexOf(u8, raw_slice, "\"usage\"")) |u_idx| {
            const usage_slice = raw_slice[u_idx..];
            var p_tok: u32 = 0;
            var c_tok: u32 = 0;
            var t_tok: u32 = 0;

            if (std.mem.indexOf(u8, usage_slice, "\"prompt_tokens\":")) |pt_idx| {
                const start = pt_idx + 16;
                var end = start;
                while (end < usage_slice.len and (usage_slice[end] == ' ' or (usage_slice[end] >= '0' and usage_slice[end] <= '9'))) : (end += 1) {}
                const trimmed_num = std.mem.trim(u8, usage_slice[start..end], " ");
                p_tok = std.fmt.parseInt(u32, trimmed_num, 10) catch 0;
            }
            if (std.mem.indexOf(u8, usage_slice, "\"completion_tokens\":")) |ct_idx| {
                const start = ct_idx + 20;
                var end = start;
                while (end < usage_slice.len and (usage_slice[end] == ' ' or (usage_slice[end] >= '0' and usage_slice[end] <= '9'))) : (end += 1) {}
                const trimmed_num = std.mem.trim(u8, usage_slice[start..end], " ");
                c_tok = std.fmt.parseInt(u32, trimmed_num, 10) catch 0;
            }
            if (std.mem.indexOf(u8, usage_slice, "\"total_tokens\":")) |tt_idx| {
                const start = tt_idx + 15;
                var end = start;
                while (end < usage_slice.len and (usage_slice[end] == ' ' or (usage_slice[end] >= '0' and usage_slice[end] <= '9'))) : (end += 1) {}
                const trimmed_num = std.mem.trim(u8, usage_slice[start..end], " ");
                t_tok = std.fmt.parseInt(u32, trimmed_num, 10) catch 0;
            }
            if (t_tok == 0) t_tok = p_tok + c_tok;

            if (p_tok > 0 or c_tok > 0 or t_tok > 0) {
                last_usage = .{
                    .prompt_tokens = p_tok,
                    .completion_tokens = c_tok,
                    .total_tokens = t_tok,
                };
                session_total_tokens += t_tok;
            }
        }

        // 1. Extract reasoning if present ("reasoning":"...")
        if (std.mem.indexOf(u8, raw_slice, "\"reasoning\":\"")) |r_idx| {
            const r_start = r_idx + 13;
            var r_end = r_start;
            var r_escaped = false;
            while (r_end < raw_slice.len) {
                const c = raw_slice[r_end];
                if (c == '\\') {
                    r_escaped = !r_escaped;
                } else if (c == '"' and !r_escaped) {
                    break;
                } else {
                    r_escaped = false;
                }
                r_end += 1;
            }

            const raw_reasoning = raw_slice[r_start..r_end];
            if (raw_reasoning.len > 0) {
                const prefix = "<think>\n";
                @memcpy(out_buf[out_cursor .. out_cursor + prefix.len], prefix);
                out_cursor += prefix.len;

                var i: usize = 0;
                while (i < raw_reasoning.len and out_cursor < out_buf.len - 12) {
                    if (raw_reasoning[i] == '\\' and i + 1 < raw_reasoning.len) {
                        if (raw_reasoning[i + 1] == 'n') {
                            out_buf[out_cursor] = '\n';
                            out_cursor += 1;
                            i += 2;
                            continue;
                        } else if (raw_reasoning[i + 1] == '"') {
                            out_buf[out_cursor] = '"';
                            out_cursor += 1;
                            i += 2;
                            continue;
                        }
                    }
                    out_buf[out_cursor] = raw_reasoning[i];
                    out_cursor += 1;
                    i += 1;
                }

                const suffix = "\n</think>\n\n";
                @memcpy(out_buf[out_cursor .. out_cursor + suffix.len], suffix);
                out_cursor += suffix.len;
            }
        }

        // 2. Extract content ("content":"...")
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

        // 3. Extract API Error if present ("error":{"message":"...")
        if (std.mem.indexOf(u8, raw_slice, "\"message\":\"")) |err_idx| {
            const err_start = err_idx + 11;
            var err_end = err_start;
            while (err_end < raw_slice.len and raw_slice[err_end] != '"') : (err_end += 1) {}
            const err_msg = raw_slice[err_start..err_end];
            const err_banner = std.fmt.bufPrint(out_buf, "[OpenRouter API Error]: {s}", .{err_msg}) catch err_msg;
            return err_banner.len;
        }

        return out_cursor;
    }
};
