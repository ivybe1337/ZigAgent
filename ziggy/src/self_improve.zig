const std = @import("std");
const sys = @import("sys.zig");
const tui = @import("tui.zig");
const tools = @import("tools.zig");

pub const SelfImprovementEngine = struct {
    allocator: std.mem.Allocator,
    source_root: []const u8 = "src",
    evolution_generation: u32 = 1,

    pub fn init(allocator: std.mem.Allocator) SelfImprovementEngine {
        return .{
            .allocator = allocator,
            .source_root = "src",
            .evolution_generation = 1,
        };
    }

    /// Codebase Module Audit & Compilation Pipeline
    pub fn analyzeSelf(self: *SelfImprovementEngine) void {
        std.debug.print("\n{s}=== ZIGAGENT CODEBASE MODULE AUDIT ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
        
        const self_modules = [_]struct { name: []const u8, role: []const u8 }{
            .{ .name = "src/agent.zig", .role = "Autonomous ReAct Execution Loop & Dispatch" },
            .{ .name = "src/memory.zig", .role = "L1 Ring Buffer & L3 Merkle Root Tracking" },
            .{ .name = "src/http.zig", .role = "Fast LPU Inference Client & Reasoning Parser" },
            .{ .name = "src/tools.zig", .role = "Native File, Command & Git Execution Suite" },
            .{ .name = "src/server.zig", .role = "Local HTTP & WebSocket Canvas Server (Port 4040)" },
            .{ .name = "src/recursive_thought.zig", .role = "Multi-Pass Deliberation Pipeline" },
            .{ .name = "src/self_improve.zig", .role = "Self-Recompilation & State Persistence" },
        };

        std.debug.print("  {s}Module Status Check (Generation {d}):{s}\n", .{ tui.TUI.C_WHITE, self.evolution_generation, tui.TUI.C_RESET });
        for (self_modules) |m| {
            var exists = sys.Sys.open(@ptrCast(m.name), sys.O_RDONLY);
            if (exists < 0) {
                var alt_buf: [256]u8 = undefined;
                if (std.fmt.bufPrint(&alt_buf, "ziggy/{s}", .{m.name})) |alt_p| {
                    alt_buf[alt_p.len] = 0;
                    exists = sys.Sys.open(@ptrCast(&alt_buf[0]), sys.O_RDONLY);
                } else |_| {}
            }
            const status_str = if (exists >= 0) "\x1b[38;2;49;196;141m[PRESENT]\x1b[0m" else "\x1b[38;2;255;107;53m[MISSING]\x1b[0m";
            if (exists >= 0) _ = sys.Sys.close(exists);

            std.debug.print("  • {s} \x1b[1;38;2;255;107;53m{s:<28}\x1b[0m : {s}\n", .{
                status_str, m.name, m.role,
            });
        }

        std.debug.print("\n  {s}Self-Recompilation Pipeline:{s}\n", .{ tui.TUI.C_AQUA, tui.TUI.C_RESET });
        std.debug.print("  1. Run structural AST and delimiter validation on local source.\n", .{});
        std.debug.print("  2. Compile release binary: `zig build -Doptimize=ReleaseFast`.\n", .{});
        std.debug.print("  3. Persist active state and Merkle root to `.ziggy/rehydration.json`.\n", .{});
        std.debug.print("  4. Resume execution in updated generation binary with preserved context.\n", .{});
        std.debug.print("\n{s}Use /evolve run to trigger an automated self-recompilation check.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
    }

    /// Trigger Automated Recompilation and State Rehydration
    pub fn triggerAutonomousEvolution(self: *SelfImprovementEngine, merkle_root: []const u8) bool {
        std.debug.print("\n\x1b[38;2;0;242;254m⚡ [RECOMPILATION]:\x1b[0m Commencing build verification...\n", .{});

        // 1. Save rehydration state
        var state_buf: [1024]u8 = undefined;
        const state_json = std.fmt.bufPrint(
            &state_buf,
            "{{\"generation\":{d},\"merkle_root\":\"{s}\",\"timestamp\":{d}}}\n",
            .{ self.evolution_generation + 1, merkle_root, sys.currentTimestamp() },
        ) catch "";

        _ = sys.writeEntireFile(".ziggy/rehydration.json", state_json);
        std.debug.print("  • Persisted state to .ziggy/rehydration.json\n", .{});

        // 2. Recompile binary
        std.debug.print("  • Building release binary via Zig compiler...\n", .{});
        const native_tools = tools.NativeTools{};
        const build_res = native_tools.executeCommand(self.allocator, "zig build -Doptimize=ReleaseFast");

        if (!build_res.success) {
            std.debug.print("\x1b[38;2;255;107;53m✘ Build verification failed. Keeping current active binary.\x1b[0m\n", .{});
            return false;
        }

        std.debug.print("\x1b[38;2;49;196;141m✔ Recompilation successful! Binary updated.\x1b[0m\n\n", .{});
        self.evolution_generation += 1;
        return true;
    }
};
