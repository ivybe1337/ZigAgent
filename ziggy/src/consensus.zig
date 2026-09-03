const std = @import("std");
const security = @import("security.zig");
const ast_guard = @import("ast_guard.zig");

pub const PerspectiveVote = struct {
    lens_name: []const u8,
    approved: bool,
    confidence: f32,
    critique: []const u8,
};

pub const ConsensusCouncil = struct {
    pub fn evaluateProposal(
        _: std.mem.Allocator,
        proposal: []const u8,
        votes_buf: []PerspectiveVote,
    ) usize {
        if (votes_buf.len < 3) return 0;

        // 1. Security & Sandboxing Lens
        const audit = security.SecurityEngine.auditCommand(proposal);
        const has_secret = std.mem.indexOf(u8, proposal, "sk-") != null or std.mem.indexOf(u8, proposal, "gsk_") != null;
        const sec_ok = audit.is_safe and !has_secret;

        votes_buf[0] = PerspectiveVote{
            .lens_name = "Security & Sandboxing Lens",
            .approved = sec_ok,
            .confidence = if (sec_ok) 0.98 else 0.40,
            .critique = if (sec_ok) "Zero destructive patterns or exposed credential tokens found." else "Security alert: Proposal contains sensitive tokens or destructive commands.",
        };

        // 2. Performance & Memory Lens
        const is_huge = proposal.len > 16384;
        const perf_ok = !is_huge;

        votes_buf[1] = PerspectiveVote{
            .lens_name = "Performance & Memory Lens",
            .approved = perf_ok,
            .confidence = if (perf_ok) 0.95 else 0.60,
            .critique = if (perf_ok) "Bounded token payload within fast LPU context thresholds." else "Performance warning: Payload length exceeds optimal single-turn window.",
        };

        // 3. Architecture & Syntax Integrity Lens
        const syntax_res = ast_guard.ASTGuard.validateBalancedDelimiters(proposal);
        const syntax_ok = syntax_res.valid;

        votes_buf[2] = PerspectiveVote{
            .lens_name = "Architecture & Syntax Integrity Lens",
            .approved = syntax_ok,
            .confidence = if (syntax_ok) 0.97 else 0.50,
            .critique = if (syntax_ok) "Balanced structural delimiters and modular execution boundaries." else "Syntax warning: Unbalanced brackets, braces, or quotation delimiters detected.",
        };

        return 3;
    }
};
