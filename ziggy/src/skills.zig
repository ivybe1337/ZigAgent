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
        for (self.skills.items) |s| {
            if (std.mem.startsWith(u8, s.path, "/")) {
                self.allocator.free(s.name);
                self.allocator.free(s.path);
            }
        }
        self.skills.deinit(self.allocator);
    }

    pub fn discoverSkills(self: *SkillManager) void {
        // 1. Built-in Core Skills
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

        // 2. Discover local skills from ~/.agent/skills/
        const home = sys.Sys.getenv("HOME") orelse ".";
        const home_len = std.mem.sliceTo(home, 0).len;
        var skills_dir_buf: [512]u8 = undefined;
        const skills_dir = std.fmt.bufPrint(&skills_dir_buf, "{s}/.agent/skills", .{home[0..home_len]}) catch return;

        var cmd_buf: [1024]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "ls -1 \"{s}\" 2>/dev/null | head -n 30", .{skills_dir}) catch return;
        cmd_buf[cmd.len] = 0;

        const pipe = sys.Sys.popen(@ptrCast(&cmd_buf[0]), "r") orelse return;
        defer _ = sys.Sys.pclose(pipe);

        var raw_buf: [4096]u8 = undefined;
        const bytes_read = sys.Sys.fread(@ptrCast(&raw_buf[0]), 1, raw_buf.len - 1, pipe);
        if (bytes_read > 0) {
            raw_buf[bytes_read] = 0;
            var lines = std.mem.splitScalar(u8, raw_buf[0..bytes_read], '\n');
            while (lines.next()) |line| {
                const tr = std.mem.trim(u8, line, " \t\r");
                if (tr.len == 0) continue;

                var exists = false;
                for (self.skills.items) |existing| {
                    if (std.mem.eql(u8, existing.name, tr)) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    const dup_name = self.allocator.dupe(u8, tr) catch continue;
                    const path_alloc = std.fmt.allocPrint(self.allocator, "{s}/{s}/SKILL.md", .{ skills_dir, tr }) catch continue;

                    self.skills.append(self.allocator, .{
                        .name = dup_name,
                        .description = "Local domain playbook loaded from ~/.agent/skills",
                        .path = path_alloc,
                        .is_loaded = false,
                    }) catch {};
                }
            }
        }
    }

    pub fn listSkills(self: *const SkillManager) void {
        std.debug.print("\n{s}=== ZIGAGENT SKILL SYSTEM & DOMAIN PLAYBOOKS ({d} Loaded) ==={s}\n", .{ tui.TUI.C_CYAN, self.skills.items.len, tui.TUI.C_RESET });
        for (self.skills.items) |s| {
            const status = if (s.is_loaded) "\x1b[38;2;49;196;141m[ACTIVE]\x1b[0m" else "\x1b[38;2;139;157;175m[READY]\x1b[0m";
            std.debug.print("  • {s} \x1b[1;38;2;255;107;53m{s:<28}\x1b[0m : {s}\n", .{
                status, s.name, s.description,
            });
        }
        std.debug.print("\n{s}Use /skill <name> to activate a skill, or /skills to list.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }

    pub fn activateSkill(self: *SkillManager, name: []const u8) bool {
        for (self.skills.items) |*s| {
            if (std.mem.eql(u8, s.name, name)) {
                s.is_loaded = true;
                if (!std.mem.startsWith(u8, s.path, "builtin://")) {
                    if (sys.readEntireFile(self.allocator, s.path, 16384)) |doc| {
                        self.active_skill_prompt = doc;
                    }
                }
                std.debug.print("{s}✔ Activated skill playbook: {s}{s}\n", .{ tui.TUI.C_AQUA, name, tui.TUI.C_RESET });
                return true;
            }
        }
        std.debug.print("{s}Skill '{s}' not found. Type /skills to see available playbooks.{s}\n", .{ tui.TUI.C_ORANGE, name, tui.TUI.C_RESET });
        return false;
    }
};
