const std = @import("std");
const sys = @import("sys.zig");
const ast_guard = @import("ast_guard.zig");

pub const CandidateBranch = struct {
    branch_id: [32]u8,
    hypothesis: []const u8,
    score: f32,
    syntax_ok: bool,
    verified: bool,
};

pub const SpeculativeEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SpeculativeEngine {
        return .{ .allocator = allocator };
    }

    pub fn evaluateCandidates(
        self: *SpeculativeEngine,
        goal: []const u8,
        candidates: []const []const u8,
        results_buf: []CandidateBranch,
    ) usize {
        _ = self;
        var count: usize = 0;
        for (candidates, 0..) |cand, i| {
            if (count >= results_buf.len) break;

            var id_buf: [32]u8 = undefined;
            const id_str = std.fmt.bufPrint(&id_buf, "branch-spec-{d}", .{i + 1}) catch "branch-spec-0";
            var branch_id: [32]u8 = [_]u8{0} ** 32;
            @memcpy(branch_id[0..id_str.len], id_str);

            // Real delimiter syntax verification
            const syntax_res = ast_guard.ASTGuard.validateBalancedDelimiters(cand);
            const syntax_ok = syntax_res.valid;

            // Relevance scoring based on keyword overlap with goal
            var relevance: f32 = 0.70;
            if (goal.len > 0 and cand.len > 0) {
                var goal_words = std.mem.splitScalar(u8, goal, ' ');
                var matches: f32 = 0;
                var total_words: f32 = 0;
                while (goal_words.next()) |w| {
                    if (w.len > 3) {
                        total_words += 1;
                        if (std.mem.indexOf(u8, cand, w) != null) matches += 1;
                    }
                }
                if (total_words > 0) {
                    relevance += (matches / total_words) * 0.25;
                }
            }
            if (!syntax_ok) relevance *= 0.5;

            results_buf[count] = CandidateBranch{
                .branch_id = branch_id,
                .hypothesis = cand,
                .score = relevance,
                .syntax_ok = syntax_ok,
                .verified = (relevance >= 0.75 and syntax_ok),
            };
            count += 1;
        }
        return count;
    }
};
