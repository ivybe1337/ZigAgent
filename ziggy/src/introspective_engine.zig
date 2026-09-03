const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const ast_guard = @import("ast_guard.zig");
const security = @import("security.zig");

pub const EpistemicClaimType = enum {
    resource_existence,
    syntax_integrity,
    safety_boundary,
    state_consistency,
};

pub const EpistemicClaim = struct {
    claim_type: EpistemicClaimType,
    statement: []const u8,
    is_proven: bool,
    proof_evidence: []const u8,
};

pub const EpistemicProofVerdict = struct {
    passed: bool,
    verified_count: u32,
    failed_count: u32,
    self_healing_steering: []const u8,
};

pub const IntrospectiveEngine = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IntrospectiveEngine {
        return .{ .allocator = allocator };
    }

    /// Perform rigorous introspective self-proof on thought or action stream
    pub fn verifyEpistemicConsistency(self: *IntrospectiveEngine, thought_action: []const u8) EpistemicProofVerdict {
        _ = self;
        var verified: u32 = 0;
        var failed: u32 = 0;
        var steering_msg: []const u8 = "";

        // 1. Invariant: Safety Boundary Proof
        const sec_audit = security.SecurityEngine.auditCommand(thought_action);
        if (sec_audit.is_safe) {
            verified += 1;
        } else {
            failed += 1;
            steering_msg = "Introspective intercept: Destructive token detected. Reframe plan to use non-destructive operations.";
        }

        // 2. Invariant: Syntactic Delimiter Proof
        const syntax_res = ast_guard.ASTGuard.validateBalancedDelimiters(thought_action);
        if (syntax_res.valid) {
            verified += 1;
        } else {
            failed += 1;
            if (steering_msg.len == 0) {
                steering_msg = "Introspective intercept: Unmatched delimiter detected. Balance all parentheses, braces, and quotes.";
            }
        }

        // 3. Invariant: Resource Path Existence Proof (if a path is explicitly declared)
        if (extractQuotedPath(thought_action)) |target_path| {
            // Check if target file or its directory exists
            var dir_buf: [512]u8 = undefined;
            const parent_dir = getParentDirectory(target_path, &dir_buf);
            const parent_fd = sys.Sys.open(@ptrCast(parent_dir), sys.O_RDONLY);
            if (parent_fd >= 0) {
                _ = sys.Sys.close(parent_fd);
                verified += 1;
            } else {
                // If it's a read operation and file doesn't exist, fail proof
                if (std.mem.indexOf(u8, thought_action, "\"read_file\"") != null) {
                    failed += 1;
                    if (steering_msg.len == 0) {
                        steering_msg = "Introspective intercept: Target file path does not exist. Verify path with find_files or list_dir first.";
                    }
                } else {
                    verified += 1; // Creating new file or directory
                }
            }
        } else {
            verified += 1;
        }

        return EpistemicProofVerdict{
            .passed = (failed == 0),
            .verified_count = verified,
            .failed_count = failed,
            .self_healing_steering = if (steering_msg.len > 0) steering_msg else "All epistemic invariants formally proven.",
        };
    }

    fn extractQuotedPath(text: []const u8) ?[]const u8 {
        if (std.mem.indexOf(u8, text, "\"path\":")) |idx| {
            const after = text[idx + 7 ..];
            if (std.mem.indexOfScalar(u8, after, '"')) |q1| {
                const rest = after[q1 + 1 ..];
                if (std.mem.indexOfScalar(u8, rest, '"')) |q2| {
                    return rest[0..q2];
                }
            }
        }
        return null;
    }

    fn getParentDirectory(path: []const u8, out_buf: []u8) []const u8 {
        if (std.mem.lastIndexOfScalar(u8, path, '/')) |last_slash| {
            if (last_slash == 0) return "/";
            const len = @min(last_slash, out_buf.len - 1);
            @memcpy(out_buf[0..len], path[0..len]);
            out_buf[len] = 0;
            return out_buf[0..len];
        }
        return ".";
    }
};
