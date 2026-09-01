const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");

pub const SkillItem = struct {
    name: []const u8,
    description: []const u8,
    path: []const u8,
    is_loaded: bool = false,
};

pub const SkillManager = struct {
    allocator: std.mem.Allocator,
    skills: std.ArrayList(SkillItem),
    active_skill_prompt: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) SkillManager {
        var mgr = SkillManager{
            .allocator = allocator,
            .skills = .empty,
            .active_skill_prompt = null,
        };
        mgr.discoverSkills();
        return mgr;
    }

    pub fn deinit(self: *SkillManager) void {
        self.skills.deinit(self.allocator);
    }

    pub fn discoverSkills(self: *SkillManager) void {
        // Register core built-in domain skills
        const builtin_skills = [_]SkillItem{
            .{ .name = "systematic-debugging", .description = "Root-cause investigation, invariant tracing, and non-destructive triage", .path = "builtin://debugging" },
            .{ .name = "tdd-workflow", .description = "Red-Green-Refactor test-driven development with zero-regression guards", .path = "builtin://tdd" },
            .{ .name = "ast-architecture", .description = "AST structural integrity synthesis and clean delimiter preservation", .path = "builtin://ast" },
            .{ .name = "omnilattice-sync", .description = "Cross-agent state synchronization over Merkle Forest DAGs", .path = "builtin://omnilattice" },
            .{ .name = "performance-optimization", .description = "Zero-allocation inline buffers, SIMD primitives, and arena recycling", .path = "builtin://perf" },
            .{ .name = "api-security-audit", .description = "OWASP validation, input sanitization, and access control testing", .path = "builtin://security" },
        };

        for (builtin_skills) |s| {
            self.skills.append(self.allocator, s) catch {};
        }
    }

    pub fn listSkills(self: *const SkillManager) void {
        std.debug.print("\n{s}=== ZIGAGENT SKILL SYSTEM & SPECIALIZED PLAYBOOKS ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        for (self.skills.items) |s| {
            const status = if (s.is_loaded) "\x1b[38;2;49;196;141m[ACTIVE]\x1b[0m" else "\x1b[38;2;139;157;175m[READY]\x1b[0m";
            std.debug.print("  • {s} \x1b[1;38;2;255;107;53m{s:<26}\x1b[0m : {s}\n", .{
                status, s.name, s.description,
            });
        }
        std.debug.print("\n{s}Use /skill <name> to activate a skill, or /skills to list.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }

    pub fn activateSkill(self: *SkillManager, name: []const u8) bool {
        for (self.skills.items) |*s| {
            if (std.mem.eql(u8, s.name, name)) {
                s.is_loaded = true;
                std.debug.print("{s}✔ Activated skill playbook: {s}{s}\n", .{ tui.TUI.C_AQUA, name, tui.TUI.C_RESET });
                return true;
            }
        }
        std.debug.print("{s}Skill '{s}' not found. Type /skills to see available playbooks.{s}\n", .{ tui.TUI.C_ORANGE, name, tui.TUI.C_RESET });
        return false;
    }
};
