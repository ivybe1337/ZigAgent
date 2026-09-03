const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const MemoryNode = struct {
    key: []const u8,
    content: []const u8,
    energy: f32 = 50.0,
    last_accessed: i64,
    access_count: u32 = 1,
    associations: std.ArrayList([]const u8),
};

pub const ThermodynamicMemory = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(MemoryNode),
    storage_path: []const u8,
    decay_rate: f32 = 0.005, // Energy loss per second

    pub fn init(allocator: std.mem.Allocator) ThermodynamicMemory {
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        const dir = std.fmt.allocPrint(allocator, "{s}/.ziggy/memory", .{home[0..home_len]}) catch ".";
        defer if (!std.mem.eql(u8, dir, ".")) allocator.free(dir);
        _ = sys.makeDirAll(dir);
        const path = std.fmt.allocPrint(allocator, "{s}/thermodynamic_graph.json", .{dir}) catch "thermodynamic_graph.json";

        var mem = ThermodynamicMemory{
            .allocator = allocator,
            .nodes = .empty,
            .storage_path = path,
            .decay_rate = 0.005,
        };
        mem.loadFromDisk();
        return mem;
    }

    pub fn deinit(self: *ThermodynamicMemory) void {
        self.saveToDisk();
        for (self.nodes.items) |*n| {
            self.allocator.free(n.key);
            self.allocator.free(n.content);
            for (n.associations.items) |a| self.allocator.free(a);
            n.associations.deinit(self.allocator);
        }
        self.nodes.deinit(self.allocator);
        self.allocator.free(self.storage_path);
    }

    /// Inject or excite concept memory node with activation energy
    pub fn excite(self: *ThermodynamicMemory, key: []const u8, content: []const u8) void {
        const now = sys.currentTimestamp();
        self.applyThermodynamicDecay(now);

        for (self.nodes.items) |*n| {
            if (std.mem.eql(u8, n.key, key)) {
                n.energy = @min(100.0, n.energy + 35.0);
                n.last_accessed = now;
                n.access_count += 1;
                if (content.len > 0 and !std.mem.eql(u8, n.content, content)) {
                    self.allocator.free(n.content);
                    n.content = self.allocator.dupe(u8, content) catch "";
                }
                return;
            }
        }

        // Create new excited node
        const assoc: std.ArrayList([]const u8) = .empty;
        const dup_key = self.allocator.dupe(u8, key) catch return;
        const dup_content = self.allocator.dupe(u8, content) catch return;

        self.nodes.append(self.allocator, .{
            .key = dup_key,
            .content = dup_content,
            .energy = 85.0, // Initial high activation
            .last_accessed = now,
            .access_count = 1,
            .associations = assoc,
        }) catch {};
    }

    /// Establish associative holographic resonance between two concepts
    pub fn linkConcepts(self: *ThermodynamicMemory, key_a: []const u8, key_b: []const u8) void {
        if (std.mem.eql(u8, key_a, key_b)) return;

        for (self.nodes.items) |*n| {
            if (std.mem.eql(u8, n.key, key_a)) {
                var found = false;
                for (n.associations.items) |a| {
                    if (std.mem.eql(u8, a, key_b)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    const dup = self.allocator.dupe(u8, key_b) catch continue;
                    n.associations.append(self.allocator, dup) catch {};
                    n.energy = @min(100.0, n.energy + 15.0); // Mutual resonance excitation
                }
            }
        }
    }

    /// Query associative working memory graph by relevance and thermal energy
    pub fn queryWorkingMemory(self: *ThermodynamicMemory, query: []const u8, out_buf: []u8) usize {
        const now = sys.currentTimestamp();
        self.applyThermodynamicDecay(now);

        var cursor: usize = 0;
        const header = "=== THERMODYNAMIC WORKING MEMORY (L1 Active Engrams) ===\n";
        const h_len = @min(header.len, out_buf.len);
        @memcpy(out_buf[0..h_len], header[0..h_len]);
        cursor += h_len;

        var matches: usize = 0;
        for (self.nodes.items) |*n| {
            const is_relevant = query.len == 0 or std.mem.indexOf(u8, n.key, query) != null or std.mem.indexOf(u8, n.content, query) != null;
            if (is_relevant and n.energy >= 20.0 and cursor < out_buf.len - 100) {
                var line_buf: [512]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "• [{s}] (Energy: {d:.1}%, Accesses: {d})\n  {s}\n", .{
                    n.key, n.energy, n.access_count, n.content,
                }) catch continue;
                const copy_len = @min(line.len, out_buf.len - cursor);
                @memcpy(out_buf[cursor .. cursor + copy_len], line[0..copy_len]);
                cursor += copy_len;
                matches += 1;
                // Excite on retrieval
                n.energy = @min(100.0, n.energy + 10.0);
                n.last_accessed = now;
            }
        }

        if (matches == 0 and cursor < out_buf.len - 80) {
            const empty_msg = "• No working memory nodes currently above thermal activation threshold.\n";
            const copy_len = @min(empty_msg.len, out_buf.len - cursor);
            @memcpy(out_buf[cursor .. cursor + copy_len], empty_msg[0..copy_len]);
            cursor += copy_len;
        }

        out_buf[cursor] = 0;
        return cursor;
    }

    /// Apply half-life cooling based on elapsed time: E(t) = E0 - decay * dt
    fn applyThermodynamicDecay(self: *ThermodynamicMemory, current_time: i64) void {
        for (self.nodes.items) |*n| {
            const dt = @as(f32, @floatFromInt(@max(0, current_time - n.last_accessed)));
            const loss = dt * self.decay_rate;
            n.energy = @max(5.0, n.energy - loss);
        }
    }

    fn saveToDisk(self: *ThermodynamicMemory) void {
        var file_buf: std.ArrayList(u8) = .empty;
        defer file_buf.deinit(self.allocator);

        file_buf.appendSlice(self.allocator, "[\n") catch return;
        for (self.nodes.items, 0..) |n, i| {
            const comma = if (i + 1 < self.nodes.items.len) "," else "";
            var node_buf: [1024]u8 = undefined;
            const line = std.fmt.bufPrint(
                &node_buf,
                "  {{\"key\":\"{s}\",\"content\":\"{s}\",\"energy\":{d:.2},\"access_count\":{d}}}{s}\n",
                .{ n.key, n.content, n.energy, n.access_count, comma },
            ) catch continue;
            file_buf.appendSlice(self.allocator, line) catch continue;
        }
        file_buf.appendSlice(self.allocator, "]\n") catch return;

        _ = sys.writeEntireFile(self.storage_path, file_buf.items);
    }

    fn loadFromDisk(self: *ThermodynamicMemory) void {
        const data = sys.readEntireFile(self.allocator, self.storage_path, 1024 * 64) orelse return;
        defer self.allocator.free(data);

        var lines = std.mem.splitScalar(u8, data, '\n');
        while (lines.next()) |line| {
            const tr = std.mem.trim(u8, line, " \t\r,[]");
            if (tr.len == 0) continue;

            const key = extractField(tr, "key") orelse continue;
            const content = extractField(tr, "content") orelse "";

            self.excite(key, content);
        }
    }

    fn extractField(line: []const u8, field: []const u8) ?[]const u8 {
        var pat_buf: [64]u8 = undefined;
        const pat = std.fmt.bufPrint(&pat_buf, "\"{s}\":\"", .{field}) catch return null;
        if (std.mem.indexOf(u8, line, pat)) |idx| {
            const start = idx + pat.len;
            if (std.mem.indexOfScalar(u8, line[start..], '"')) |end_rel| {
                return line[start .. start + end_rel];
            }
        }
        return null;
    }
};
