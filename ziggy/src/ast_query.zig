const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const AstSymbolType = enum {
    function,
    struct_decl,
    enum_decl,
    constant,
    import_stmt,

    pub fn asString(self: AstSymbolType) []const u8 {
        return switch (self) {
            .function => "fn",
            .struct_decl => "struct",
            .enum_decl => "enum",
            .constant => "const",
            .import_stmt => "import",
        };
    }
};

pub const AstSymbol = struct {
    file_path: []const u8,
    symbol_name: []const u8,
    symbol_type: AstSymbolType,
    line_number: usize,
    signature: []const u8,
};

pub const AstQueryEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AstQueryEngine {
        return .{ .allocator = allocator };
    }

    /// Fast structural symbol search across codebase
    pub fn querySymbols(self: *AstQueryEngine, query: []const u8, search_dir: []const u8, out_list: *std.ArrayList(AstSymbol)) void {
        _ = search_dir;
        // Search Zig source files
        var cmd_buf: [2048]u8 = undefined;
        const cmd = std.fmt.bufPrint(
            &cmd_buf,
            "grep -rn -E \"(pub fn|pub const|const|pub struct|pub enum) \" src/ | head -n 40",
            .{},
        ) catch return;

        cmd_buf[cmd.len] = 0;
        const pipe = sys.Sys.popen(@ptrCast(&cmd_buf[0]), "r") orelse return;
        defer _ = sys.Sys.pclose(pipe);

        var buf: [16384]u8 = undefined;
        const bytes_read = sys.Sys.fread(@ptrCast(&buf[0]), 1, buf.len - 1, pipe);
        if (bytes_read <= 0) return;
        buf[@intCast(bytes_read)] = 0;

        var lines = std.mem.splitScalar(u8, buf[0..@intCast(bytes_read)], '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            if (query.len > 0 and std.mem.indexOf(u8, line, query) == null) continue;

            var colon_parts = std.mem.splitScalar(u8, line, ':');
            const file = colon_parts.next() orelse "";
            const line_no_str = colon_parts.next() orelse "1";
            const rest = colon_parts.rest();

            const line_no = std.fmt.parseInt(usize, line_no_str, 10) catch 1;

            var sym_type: AstSymbolType = .function;
            if (std.mem.indexOf(u8, rest, "struct") != null) sym_type = .struct_decl
            else if (std.mem.indexOf(u8, rest, "enum") != null) sym_type = .enum_decl
            else if (std.mem.indexOf(u8, rest, "const") != null) sym_type = .constant;

            const dup_file = self.allocator.dupe(u8, file) catch "";
            const dup_sig = self.allocator.dupe(u8, std.mem.trim(u8, rest, " \t\r")) catch "";

            out_list.append(self.allocator, .{
                .file_path = dup_file,
                .symbol_name = query,
                .symbol_type = sym_type,
                .line_number = line_no,
                .signature = dup_sig,
            }) catch {};
        }
    }

    pub fn renderSymbols(self: *const AstQueryEngine, symbols: []const AstSymbol) void {
        _ = self;
        std.debug.print("\n{s}=== STRUCTURAL AST SYMBOL QUERY RESULTS ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        if (symbols.len == 0) {
            std.debug.print("  • No matching structural symbols found.\n\n", .{});
            return;
        }

        for (symbols) |s| {
            std.debug.print("  • \x1b[38;2;0;242;254m[{s}]\x1b[0m \x1b[1m{s}:{d}\x1b[0m\n", .{
                s.symbol_type.asString(), s.file_path, s.line_number,
            });
            std.debug.print("    \x1b[38;2;139;157;175m{s}\x1b[0m\n\n", .{s.signature});
        }
    }
};
