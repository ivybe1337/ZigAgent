const std = @import("std");
const sys = @import("sys.zig");

pub const ProvenanceNodeType = enum {
    requirement,
    hypothesis,
    tool_action,
    ast_delta,
    verification_proof,
};

pub const ProvenanceNode = struct {
    id: u32,
    parent_id: ?u32,
    node_type: ProvenanceNodeType,
    description: []const u8,
    timestamp: i64,
};

pub const ProvenanceTracer = struct {
    allocator: std.mem.Allocator,
    nodes: [64]ProvenanceNode,
    count: usize,

    pub fn init(allocator: std.mem.Allocator) ProvenanceTracer {
        return .{
            .allocator = allocator,
            .nodes = undefined,
            .count = 0,
        };
    }

    pub fn addNode(self: *ProvenanceTracer, parent_id: ?u32, node_type: ProvenanceNodeType, description: []const u8) u32 {
        if (self.count >= self.nodes.len) return 0;
        const new_id: u32 = @intCast(self.count + 1);

        self.nodes[self.count] = ProvenanceNode{
            .id = new_id,
            .parent_id = parent_id,
            .node_type = node_type,
            .description = description,
            .timestamp = sys.currentTimestamp(),
        };
        self.count += 1;
        return new_id;
    }

    pub fn renderDAG(self: *const ProvenanceTracer, buffer: []u8) usize {
        var cursor: usize = 0;
        for (self.nodes[0..self.count]) |n| {
            const type_str = switch (n.node_type) {
                .requirement => "REQUIREMENT",
                .hypothesis => "HYPOTHESIS",
                .tool_action => "TOOL ACTION",
                .ast_delta => "AST DELTA",
                .verification_proof => "VERIFIED PROOF",
            };
            const parent_info = if (n.parent_id) |p| p else 0;

            const line = std.fmt.bufPrint(
                buffer[cursor..],
                "  [{d}] ➔ (Parent: {d}) [{s}] {s}\n",
                .{ n.id, parent_info, type_str, n.description },
            ) catch break;
            cursor += line.len;
        }
        return cursor;
    }
};
