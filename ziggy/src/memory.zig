const std = @import("std");
const sys = @import("sys.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const Engram = struct {
    hash_hex: [64]u8,
    heat: f32, // 1.0 = boiling hot, 0.0 = cold
    timestamp: i64,
    access_count: u32,
    salience: f32,
    content: []const u8,
    summary: []const u8,
};

pub const ThermodynamicMemory = struct {
    allocator: std.mem.Allocator,
    hot_ring: [64]?Engram,
    hot_head: usize,
    hot_count: usize,
    decay_rate: f32,
    storage_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, storage_dir: []const u8) ThermodynamicMemory {
        var ring: [64]?Engram = undefined;
        for (&ring) |*item| item.* = null;
        _ = sys.makeDirAll(storage_dir);

        return .{
            .allocator = allocator,
            .hot_ring = ring,
            .hot_head = 0,
            .hot_count = 0,
            .decay_rate = 0.05,
            .storage_dir = storage_dir,
        };
    }

    pub fn deinit(self: *ThermodynamicMemory) void {
        for (&self.hot_ring) |*slot| {
            if (slot.*) |e| {
                self.allocator.free(e.content);
                self.allocator.free(e.summary);
                slot.* = null;
            }
        }
    }

    pub fn recordTurn(self: *ThermodynamicMemory, content: []const u8, summary: []const u8, salience: f32) !void {
        var hash: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        hasher.update(content);
        hasher.final(&hash);

        var hex: [64]u8 = undefined;
        const hex_chars = "0123456789abcdef";
        for (hash, 0..) |byte, i| {
            hex[i * 2] = hex_chars[byte >> 4];
            hex[i * 2 + 1] = hex_chars[byte & 0x0F];
        }

        const dup_content = try self.allocator.dupe(u8, content);
        const dup_summary = try self.allocator.dupe(u8, summary);

        // Thermodynamic decay on all current hot items
        self.applyThermodynamicDecay();

        // Evict oldest if full
        if (self.hot_ring[self.hot_head]) |old| {
            // Consolidate to L3 Merkle Forest before eviction
            try self.persistEngramToMerkleForest(&old);
            self.allocator.free(old.content);
            self.allocator.free(old.summary);
        }

        self.hot_ring[self.hot_head] = Engram{
            .hash_hex = hex,
            .heat = 1.0,
            .timestamp = sys.currentTimestamp(),
            .access_count = 1,
            .salience = salience,
            .content = dup_content,
            .summary = dup_summary,
        };

        self.hot_head = (self.hot_head + 1) % self.hot_ring.len;
        if (self.hot_count < self.hot_ring.len) self.hot_count += 1;
    }

    pub fn applyThermodynamicDecay(self: *ThermodynamicMemory) void {
        for (&self.hot_ring) |*slot| {
            if (slot.*) |*e| {
                e.heat = @max(0.0, e.heat - self.decay_rate);
            }
        }
    }

    pub fn computeMerkleRoot(self: *const ThermodynamicMemory) [64]u8 {
        var combined_hasher = Sha256.init(.{});
        var count: usize = 0;

        for (self.hot_ring) |slot| {
            if (slot) |e| {
                combined_hasher.update(&e.hash_hex);
                count += 1;
            }
        }

        if (count == 0) {
            combined_hasher.update("EMPTY_MERKLE_FOREST_ROOT");
        }

        var root_hash: [32]u8 = undefined;
        combined_hasher.final(&root_hash);

        var hex: [64]u8 = undefined;
        const hex_chars = "0123456789abcdef";
        for (root_hash, 0..) |byte, i| {
            hex[i * 2] = hex_chars[byte >> 4];
            hex[i * 2 + 1] = hex_chars[byte & 0x0F];
        }

        return hex;
    }

    pub fn searchEngrams(self: *const ThermodynamicMemory, query: []const u8, buffer: []u8) usize {
        var cursor: usize = 0;
        for (self.hot_ring) |slot| {
            if (slot) |e| {
                if (std.mem.indexOf(u8, e.summary, query) != null or std.mem.indexOf(u8, e.content, query) != null) {
                    const line = std.fmt.bufPrint(
                        buffer[cursor..],
                        " • [{s:.16}] Heat: {d:.0}% | {s}\n",
                        .{ e.hash_hex, e.heat * 100.0, e.summary },
                    ) catch break;
                    cursor += line.len;
                }
            }
        }
        return cursor;
    }

    pub fn getHotSummary(self: *const ThermodynamicMemory, buffer: []u8) usize {
        var cursor: usize = 0;
        var i: usize = 0;
        while (i < self.hot_count) : (i += 1) {
            const idx = (self.hot_head + self.hot_ring.len - 1 - i) % self.hot_ring.len;
            if (self.hot_ring[idx]) |e| {
                const prefix = " • [Heat: ";
                if (cursor + prefix.len >= buffer.len) break;
                @memcpy(buffer[cursor .. cursor + prefix.len], prefix);
                cursor += prefix.len;

                // Format heat
                const heat_int: u32 = @intFromFloat(e.heat * 100.0);
                var num_buf: [16]u8 = undefined;
                const num_slice = std.fmt.bufPrint(&num_buf, "{d}%] ", .{heat_int}) catch "";
                if (cursor + num_slice.len >= buffer.len) break;
                @memcpy(buffer[cursor .. cursor + num_slice.len], num_slice);
                cursor += num_slice.len;

                // Summary slice
                const s_len = @min(e.summary.len, buffer.len - cursor - 2);
                @memcpy(buffer[cursor .. cursor + s_len], e.summary[0..s_len]);
                cursor += s_len;

                if (cursor + 1 < buffer.len) {
                    buffer[cursor] = '\n';
                    cursor += 1;
                }
            }
        }
        return cursor;
    }

    pub fn persistEngramToMerkleForest(self: *ThermodynamicMemory, e: *const Engram) !void {
        var path_buf: [1024]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/{s}.engram", .{ self.storage_dir, e.hash_hex }) catch return;

        var json_buf: [4096]u8 = undefined;
        const json = std.fmt.bufPrint(
            &json_buf,
            \\{{
            \\  "hash": "{s}",
            \\  "timestamp": {d},
            \\  "access_count": {d},
            \\  "salience": {d:.2},
            \\  "summary": "{s}",
            \\  "content": "{s}"
            \\}}
            \\
        , .{ e.hash_hex, e.timestamp, e.access_count, e.salience, e.summary, e.content }) catch return;

        _ = sys.writeEntireFile(path, json);
    }

    pub fn persistAllHotToForest(self: *ThermodynamicMemory) void {
        for (self.hot_ring) |slot| {
            if (slot) |e| {
                self.persistEngramToMerkleForest(&e) catch {};
            }
        }

        // Save Merkle Root Manifest
        const root = self.computeMerkleRoot();
        var manifest_buf: [512]u8 = undefined;
        const manifest = std.fmt.bufPrint(
            &manifest_buf,
            "{{\"merkle_root\":\"{s}\",\"active_engrams\":{d},\"timestamp\":{d}}}\n",
            .{ root, self.hot_count, sys.currentTimestamp() },
        ) catch return;

        var manifest_path: [512]u8 = undefined;
        const p = std.fmt.bufPrint(&manifest_path, "{s}/merkle_manifest.json", .{self.storage_dir}) catch return;
        _ = sys.writeEntireFile(p, manifest);
    }

    pub fn targetedCompaction(self: *ThermodynamicMemory, target: []const u8, buffer: []u8) usize {
        var preserved: usize = 0;
        var compacted: usize = 0;

        for (&self.hot_ring) |*slot| {
            if (slot.*) |*e| {
                const matches = (target.len == 0) or
                    (std.mem.indexOf(u8, e.summary, target) != null) or
                    (std.mem.indexOf(u8, e.content, target) != null);

                if (matches) {
                    e.heat = 1.0;
                    preserved += 1;
                } else {
                    self.persistEngramToMerkleForest(e) catch {};
                    self.allocator.free(e.content);
                    self.allocator.free(e.summary);
                    slot.* = null;
                    compacted += 1;
                }
            }
        }

        if (self.hot_count >= compacted) {
            self.hot_count -= compacted;
        } else {
            self.hot_count = 0;
        }

        const report = std.fmt.bufPrint(
            buffer,
            "✔ Targeted Compaction: Preserved {d} focus engrams, consolidated {d} background engrams to Merkle DAG.\n",
            .{ preserved, compacted },
        ) catch return 0;

        return report.len;
    }
};
