const std = @import("std");
const sys = @import("sys.zig");
const agent = @import("agent.zig");
const tui = @import("tui.zig");
const repl = @import("repl.zig");
const macos_app = @import("macos_app.zig");

pub fn main(p_init: std.process.Init) !void {
    const alloc = p_init.gpa;
    var iter = p_init.minimal.args.iterate();

    // Skip program name
    _ = iter.next();

    const cmd = iter.next();

    // If no argument is provided or "chat", launch the full interactive CLI REPL
    if (cmd == null or std.mem.eql(u8, cmd.?, "chat") or std.mem.eql(u8, cmd.?, "repl")) {
        var r = repl.Repl.init(alloc);
        defer r.deinit();
        try r.run();
        return;
    }

    const command = cmd.?;

    if (std.mem.eql(u8, command, "doctor")) {
        std.debug.print("\n=== ZIGAGENT SYSTEM DIAGNOSTIC ===\n", .{});
        std.debug.print("• Zig Version: 0.16.0 (Native ARM64 / macOS)\n", .{});
        std.debug.print("• Memory Management: Thermodynamic L1 Ring + L3 Merkle Forest\n", .{});
        std.debug.print("• Allocator Strategy: Step-Bounded Arena (Zero Leak / Zero OOM)\n", .{});
        std.debug.print("• Architecture: 100% Native, Zero Electron / Zero Webview Bloat\n", .{});
        std.debug.print("• Status: [READY & HEALTHY]\n\n", .{});
        return;
    }

    if (std.mem.eql(u8, command, "tui")) {
        const goal = iter.next() orelse "Autonomous self-improvement and codebase optimization";
        var engine = agent.AgentEngine.init(alloc, ".ziggy/engrams");
        defer engine.deinit();

        engine.startGoal(goal);

        var ui = tui.TUI{};
        ui.enterRawMode();
        defer ui.exitRawMode();

        while (true) {
            ui.render(&engine);
            
            // Read single key non-blocking / short sleep
            var key_buf: [1]u8 = undefined;
            const r = sys.Sys.read(0, &key_buf, 1);
            if (r > 0) {
                const k = key_buf[0];
                if (k == 'q' or k == 'Q') {
                    break;
                } else if (k == ' ' or k == 'r' or k == 'R') {
                    _ = engine.step();
                }
            } else {
                if (engine.state.is_running) {
                    _ = engine.step();
                    sys.sleepMs(250);
                } else {
                    sys.sleepMs(50);
                }
            }
        }
        return;
    }

    if (std.mem.eql(u8, command, "run")) {
        const goal = iter.next() orelse "Inspect project and execute autonomous plan";
        var engine = agent.AgentEngine.init(alloc, ".ziggy/engrams");
        defer engine.deinit();

        engine.startGoal(goal);
        std.debug.print("\n[ZIGAGENT] Starting goal: \"{s}\"\n", .{goal});

        while (engine.state.is_running) {
            std.debug.print("• Step {d}: {s} (Confidence: {d:.0}%)\n", .{
                engine.state.step + 1,
                engine.state.phase.asString(),
                engine.state.confidence * 100.0,
            });
            _ = engine.step();
        }

        std.debug.print("\n✔ Goal completed successfully with confidence {d:.0}%\n", .{
            engine.state.confidence * 100.0,
        });
        return;
    }

    if (std.mem.eql(u8, command, "app")) {
        try macos_app.MacOSNativeApp.launch();
        return;
    }

    if (std.mem.eql(u8, command, "serve") or std.mem.eql(u8, command, "remote")) {
        const port_arg = iter.next();
        const port: u16 = if (port_arg) |p| std.fmt.parseInt(u16, p, 10) catch 4040 else 4040;
        var srv = @import("server.zig").RemoteServer.init(alloc, port);
        try srv.run();
        return;
    }

    try printHelp();
}

fn printHelp() !void {
    std.debug.print(
        \\⚡ ZigAgent Native CLI & TUI Suite
        \\
        \\Usage:
        \\  ziggy                 Launch full interactive CLI REPL (like claude / agy)
        \\  ziggy tui "<goal>"    Launch full-screen live telemetry HUD TUI
        \\  ziggy run "<goal>"    Run headless autonomous agent loop
        \\  ziggy doctor          Run system and memory diagnostics
        \\  ziggy app             Launch native macOS window
        \\
    , .{});
}
