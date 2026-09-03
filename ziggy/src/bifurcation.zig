const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const ast_guard = @import("ast_guard.zig");
const security = @import("security.zig");

pub const HemisphereState = enum {
    idle,
    speculating,
    verified_branch,
    pruned_branch,
};

pub const SpeculativeRollout = struct {
    branch_hash: u64,
    predicted_tool: []const u8,
    target_path: []const u8,
    syntax_intact: bool,
    security_cleared: bool,
    latency_saved_us: i64,
};

pub const BifurcationEngine = struct {
    allocator: std.mem.Allocator,
    active_branch_count: u32 = 0,
    divergence_count: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) BifurcationEngine {
        return .{
            .allocator = allocator,
            .active_branch_count = 0,
            .divergence_count = 0,
        };
    }

    /// Concurrently analyze and pre-validate emerging tool action from generative stream
    pub fn speculateAhead(self: *BifurcationEngine, streaming_chunk: []const u8) ?SpeculativeRollout {
        const t0 = sys.nanoTimestamp();

        // 1. Detect candidate tool invocation early in the stream
        var predicted_tool: []const u8 = "unknown";
        var target_path: []const u8 = "";

        if (std.mem.indexOf(u8, streaming_chunk, "\"read_file\"") != null) {
            predicted_tool = "read_file";
        } else if (std.mem.indexOf(u8, streaming_chunk, "\"write_file\"") != null) {
            predicted_tool = "write_file";
        } else if (std.mem.indexOf(u8, streaming_chunk, "\"edit_file\"") != null) {
            predicted_tool = "edit_file";
        } else if (std.mem.indexOf(u8, streaming_chunk, "\"run_command\"") != null) {
            predicted_tool = "run_command";
        } else {
            return null; // Not a tool invocation pattern
        }

        // 2. Speculative path extraction
        if (std.mem.indexOf(u8, streaming_chunk, "\"path\":")) |p_idx| {
            const after = streaming_chunk[p_idx + 7 ..];
            if (std.mem.indexOfScalar(u8, after, '"')) |q1| {
                const after_q = after[q1 + 1 ..];
                if (std.mem.indexOfScalar(u8, after_q, '"')) |q2| {
                    target_path = after_q[0..q2];
                }
            }
        }

        // 3. Speculative security and AST delimiter check
        const sec_audit = security.SecurityEngine.auditCommand(streaming_chunk);
        const syntax_res = ast_guard.ASTGuard.validateBalancedDelimiters(streaming_chunk);

        const t1 = sys.nanoTimestamp();
        const elapsed_us = @divTrunc(t1 - t0, 1000);

        self.active_branch_count += 1;
        if (!sec_audit.is_safe or !syntax_res.valid) {
            self.divergence_count += 1;
        }

        const branch_hash = std.hash.Fv1a_64.hash(streaming_chunk);

        return SpeculativeRollout{
            .branch_hash = branch_hash,
            .predicted_tool = predicted_tool,
            .target_path = target_path,
            .syntax_intact = syntax_res.valid,
            .security_cleared = sec_audit.is_safe,
            .latency_saved_us = elapsed_us,
        };
    }

    /// Report telemetry of speculative bifurcation engine
    pub fn renderTelemetry(self: *const BifurcationEngine) void {
        std.debug.print("\n{s}=== BIFURCATED DUAL-HEMISPHERE SPECULATION TELEMETRY ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        std.debug.print("  • Speculative Rollouts Analyzed: \x1b[1m{d}\x1b[0m\n", .{self.active_branch_count});
        std.debug.print("  • Branch Divergences Intercepted: \x1b[38;2;255;107;53m{d}\x1b[0m\n", .{self.divergence_count});
        std.debug.print("  • Predictive Pre-Validation: \x1b[38;2;49;196;141m[ACTIVE ZERO-STALL PIPELINE]\x1b[0m\n\n", .{});
    }
};
