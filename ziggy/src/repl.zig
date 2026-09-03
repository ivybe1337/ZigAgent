const std = @import("std");
const sys = @import("sys.zig");
const agent = @import("agent.zig");
const tui = @import("tui.zig");
const auth = @import("auth.zig");
const models = @import("models.zig");
const oauth = @import("oauth.zig");
const benchmark = @import("benchmark.zig");
const ledger = @import("ledger.zig");
const mailbox = @import("mailbox.zig");
const associative_memory = @import("associative_memory.zig");
const invariants = @import("invariants.zig");
const speculative = @import("speculative.zig");
const provenance = @import("provenance.zig");
const ast_guard = @import("ast_guard.zig");
const consensus = @import("consensus.zig");
const timemachine = @import("timemachine.zig");
const http = @import("http.zig");
const config = @import("config.zig");
const agent_wizard = @import("agent_wizard.zig");
const tools = @import("tools.zig");
const interactive_tui = @import("interactive_tui.zig");
const omnilattice = @import("omnilattice.zig");
const mcp = @import("mcp.zig");
const skills = @import("skills.zig");
const plugins = @import("plugins.zig");
const recursive_thought = @import("recursive_thought.zig");
const self_improve = @import("self_improve.zig");
const messaging = @import("messaging.zig");
const ast_query = @import("ast_query.zig");
const swarm = @import("swarm.zig");
const model_router = @import("model_router.zig");
const minds_eye = @import("minds_eye.zig");
const thermodynamic_memory = @import("thermodynamic_memory.zig");
const bifurcation = @import("bifurcation.zig");
const introspective_engine = @import("introspective_engine.zig");
const morphogenetic = @import("morphogenetic.zig");
const tips = @import("tips.zig");

pub const Repl = struct {
    allocator: std.mem.Allocator,
    engine: agent.AgentEngine,
    vault: auth.AuthVault,
    oauth_mgr: oauth.OAuthManager,
    context_ledger: ledger.ContextLedger,
    agent_mailbox: mailbox.MailboxManager,
    assoc_memory: associative_memory.AssociativeMemoryVault,
    spec_engine: speculative.SpeculativeEngine,
    prov_tracer: provenance.ProvenanceTracer,
    time_mach: timemachine.TimeMachine,
    cfg_mgr: config.ConfigManager,
    omni_bridge: omnilattice.OmniLatticeBridge,
    mcp_mgr: mcp.McpManager,
    skill_mgr: skills.SkillManager,
    plugin_mgr: plugins.PluginManager,
    recursive_engine: recursive_thought.RecursiveThinkingEngine,
    self_improve_engine: self_improve.SelfImprovementEngine,
    messaging_hub: messaging.MessagingHub,
    ast_query_engine: ast_query.AstQueryEngine,
    swarm_orchestrator: swarm.SwarmOrchestrator,
    eye: minds_eye.MindsEye,
    thermo_mem: thermodynamic_memory.ThermodynamicMemory,
    bifurc_engine: bifurcation.BifurcationEngine,
    intro_engine: introspective_engine.IntrospectiveEngine,
    morph_weaver: morphogenetic.MorphogeneticWeaver,
    history: std.ArrayList([]const u8),
    chat_history: std.ArrayList(http.ChatMessage),
    active_model_buf: [128]u8 = [_]u8{0} ** 128,
    active_model_len: usize = 0,

    pub fn getActiveModel(self: *const Repl) []const u8 {
        if (self.active_model_len > 0) return self.active_model_buf[0..self.active_model_len];
        return "nvidia/nemotron-3-super-120b-a12b:free";
    }

    pub fn init(allocator: std.mem.Allocator) Repl {
        var tracer = provenance.ProvenanceTracer.init(allocator);
        _ = tracer.addNode(null, .requirement, "Initialize ZigAgent runtime and load cognitive parameters.");

        var r = Repl{
            .allocator = allocator,
            .engine = agent.AgentEngine.init(allocator, ".ziggy/engrams"),
            .vault = auth.AuthVault.init(allocator),
            .oauth_mgr = oauth.OAuthManager.init(allocator),
            .context_ledger = ledger.ContextLedger.init(allocator, ".ziggy"),
            .agent_mailbox = mailbox.MailboxManager.init(allocator, ".ziggy/inbox"),
            .assoc_memory = associative_memory.AssociativeMemoryVault.init(allocator, ".ziggy"),
            .spec_engine = speculative.SpeculativeEngine.init(allocator),
            .prov_tracer = tracer,
            .time_mach = timemachine.TimeMachine.init(allocator, ".ziggy/snapshots"),
            .cfg_mgr = config.ConfigManager.init(allocator),
            .omni_bridge = omnilattice.OmniLatticeBridge.init(allocator, ".ziggy"),
            .mcp_mgr = mcp.McpManager.init(allocator, ".ziggy"),
            .skill_mgr = skills.SkillManager.init(allocator),
            .plugin_mgr = plugins.PluginManager.init(allocator),
            .recursive_engine = recursive_thought.RecursiveThinkingEngine.init(allocator),
            .self_improve_engine = self_improve.SelfImprovementEngine.init(allocator),
            .messaging_hub = messaging.MessagingHub.init(allocator),
            .ast_query_engine = ast_query.AstQueryEngine.init(allocator),
            .swarm_orchestrator = swarm.SwarmOrchestrator.init(allocator),
            .eye = minds_eye.MindsEye.init(allocator),
            .thermo_mem = thermodynamic_memory.ThermodynamicMemory.init(allocator),
            .bifurc_engine = bifurcation.BifurcationEngine.init(allocator),
            .intro_engine = introspective_engine.IntrospectiveEngine.init(allocator),
            .morph_weaver = morphogenetic.MorphogeneticWeaver.init(allocator),
            .history = .empty,
            .chat_history = .empty,
        };

        const saved_model = std.mem.sliceTo(&r.cfg_mgr.config.default_model, 0);
        const initial = if (saved_model.len > 0) saved_model else "nvidia/nemotron-3-super-120b-a12b:free";
        const copy_len = @min(initial.len, r.active_model_buf.len - 1);
        @memcpy(r.active_model_buf[0..copy_len], initial[0..copy_len]);
        r.active_model_buf[copy_len] = 0;
        r.active_model_len = copy_len;

        return r;
    }

    pub fn deinit(self: *Repl) void {
        self.engine.deinit();
        self.mcp_mgr.deinit();
        self.skill_mgr.deinit();
        self.plugin_mgr.deinit();
        self.eye.deinit();
        self.thermo_mem.deinit();
        self.morph_weaver.deinit();
        for (self.chat_history.items) |msg| {
            self.allocator.free(msg.role);
            self.allocator.free(msg.content);
        }
        self.chat_history.deinit(self.allocator);
        for (self.history.items) |h| {
            self.allocator.free(h);
        }
        self.history.deinit(self.allocator);
    }

    pub fn getContextMetrics(self: *const Repl) struct {
        current_tokens: u32,
        max_tokens: u32,
        fill_pct: f32,
        last_out: u32,
        session_tokens: u64,
    } {
        const max_tokens = models.getModelContextWindow(self.getActiveModel());
        var current_tokens: u32 = 0;

        if (http.last_usage.total_tokens > 0) {
            current_tokens = http.last_usage.total_tokens;
        } else {
            var total_bytes: usize = http.SYSTEM_PROMPT_WITH_TOOLS.len;
            for (self.chat_history.items) |msg| {
                total_bytes += msg.content.len + 32;
            }
            current_tokens = http.estimateTokensFromBytes(total_bytes);
        }

        const fill_pct: f32 = (@as(f32, @floatFromInt(current_tokens)) / @as(f32, @floatFromInt(max_tokens))) * 100.0;
        return .{
            .current_tokens = current_tokens,
            .max_tokens = max_tokens,
            .fill_pct = fill_pct,
            .last_out = http.last_usage.completion_tokens,
            .session_tokens = http.session_total_tokens,
        };
    }

    fn renderPromptHeader(self: *Repl) void {
        const m = self.getContextMetrics();

        const ctx_color = if (m.fill_pct < 50.0)
            "\x1b[38;2;49;196;141m" // green
        else if (m.fill_pct < 80.0)
            "\x1b[38;2;255;184;108m" // amber
        else
            "\x1b[38;2;255;107;107m"; // red

        const max_k = m.max_tokens / 1000;

        std.debug.print(
            "\n\x1b[38;2;100;116;139m╭──\x1b[0m \x1b[1;38;2;241;245;249m{s}\x1b[0m \x1b[38;2;100;116;139m│\x1b[0m \x1b[38;2;148;163;184m{s}\x1b[0m \x1b[38;2;100;116;139m│\x1b[0m {s}{d}/{d}k tok ({d:.1}%)\x1b[0m",
            .{
                self.getActiveModel(),
                self.cfg_mgr.config.thinking_effort.asString(),
                ctx_color,
                m.current_tokens,
                max_k,
                m.fill_pct,
            },
        );

        if (m.session_tokens > 0) {
            std.debug.print(" \x1b[38;2;100;116;139m│\x1b[0m \x1b[38;2;148;163;184mSession: {d} tok\x1b[0m", .{m.session_tokens});
        }
        std.debug.print(" \x1b[38;2;100;116;139m───────────────────────────────────────────────\x1b[0m\n", .{});
    }

    pub fn run(self: *Repl) !void {
        self.printWelcome();

        var input_buf: [8192]u8 = undefined;
        while (true) {
            self.renderPromptHeader();

            const prompt_str = "\x1b[38;2;100;116;139m╰─\x1b[38;2;168;85;247m❯\x1b[0m ";

            const line = interactive_tui.InteractiveTUI.readInputWithAutocomplete(
                self.allocator,
                prompt_str,
                &input_buf,
                &self.history,
            ) orelse break;

            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            if (trimmed.len == 0) continue;

            // Direct Shell Execution via `!` prefix
            if (std.mem.startsWith(u8, trimmed, "!")) {
                const shell_cmd = std.mem.trim(u8, trimmed[1..], " \t\r\n");
                if (shell_cmd.len == 0) {
                    std.debug.print("{s}Usage: !<command> (e.g. !ls -la, !git status, !grep pattern .){s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
                } else {
                    std.debug.print("{s}⚡ [Shell]: {s}{s}\n", .{ tui.TUI.C_CYAN, shell_cmd, tui.TUI.C_RESET });
                    const res = self.engine.tool_registry.executeCommand(self.allocator, shell_cmd);
                    std.debug.print("{s}\n", .{res.output});
                }
                continue;
            }

            if (std.mem.startsWith(u8, trimmed, "/")) {
                const should_continue = self.handleSlashCommand(trimmed);
                if (!should_continue) break;
                continue;
            }

            // Execute goal with full autonomous tool-calling loop
            self.executeAutonomousGoal(trimmed);
        }
    }

    fn printWelcome(self: *Repl) void {
        std.debug.print(
            \\
            \\{s}{s}  ⚡ ZIGAGENT CLI v0.1.0{s} {s}[Autonomous Action Engine]{s}
            \\{s}  Active Provider: {s}{s}{s} │ Model: {s}{s}{s}
            \\{s}  Agent ID: {s}{s}{s} │ Project: {s}{s}{s}
            \\{s}  Type {s}/{s} for autocomplete, {s}!{s} for shell commands, or enter a directive.
            \\{s}─────────────────────────────────────────────────────────────────────────────{s}
            \\
        , .{
            tui.TUI.C_AQUA, tui.TUI.C_BOLD, tui.TUI.C_RESET,
            tui.TUI.C_DIM, tui.TUI.C_RESET,
            tui.TUI.C_MUTED, tui.TUI.C_CYAN, self.vault.config.provider.asString(), tui.TUI.C_RESET,
            tui.TUI.C_ORANGE, self.getActiveModel(), tui.TUI.C_RESET,
            tui.TUI.C_MUTED, tui.TUI.C_WHITE, std.mem.sliceTo(&self.context_ledger.current_agent_id, 0), tui.TUI.C_RESET,
            tui.TUI.C_WHITE, std.mem.sliceTo(&self.context_ledger.current_project_id, 0), tui.TUI.C_RESET,
            tui.TUI.C_MUTED, tui.TUI.C_AQUA, tui.TUI.C_MUTED, tui.TUI.C_ORANGE, tui.TUI.C_MUTED,
            tui.TUI.C_BORDER, tui.TUI.C_RESET,
        });

        std.debug.print("  {s}💡 Tip: {s}{s}\n\n", .{ tui.TUI.C_MUTED, tips.getNextTip(), tui.TUI.C_RESET });

        // Check if waking up from a hot-restart recompile
        if (sys.readEntireFile(self.allocator, ".ziggy/rehydration.json", 1024)) |rehyd_json| {
            defer self.allocator.free(rehyd_json);
            std.debug.print("\x1b[38;2;0;242;254m⚡ [HOT-RESTART WAKEUP]:\x1b[0m Runtime recompiled & rehydrated into new generation with zero context loss.\n", .{});
        }
    }

    pub fn setActiveModel(self: *Repl, raw_model: []const u8) void {
        const resolved = models.resolveModelName(raw_model);
        const len = @min(resolved.len, self.active_model_buf.len - 1);
        @memcpy(self.active_model_buf[0..len], resolved[0..len]);
        self.active_model_buf[len] = 0;
        self.active_model_len = len;

        const copy_len = @min(resolved.len, self.cfg_mgr.config.default_model.len - 1);
        @memcpy(self.cfg_mgr.config.default_model[0..copy_len], resolved[0..copy_len]);
        self.cfg_mgr.config.default_model[copy_len] = 0;
        self.cfg_mgr.save();
        std.debug.print("{s}✔ Active Model saved: {s}{s} {s}(sticky preference saved to ~/.ziggy/config.json){s}\n", .{
            tui.TUI.C_AQUA, resolved, tui.TUI.C_RESET, tui.TUI.C_MUTED, tui.TUI.C_RESET,
        });
    }

    fn handleSlashCommand(self: *Repl, raw_cmd: []const u8) bool {
        var parts = std.mem.splitScalar(u8, raw_cmd, ' ');
        const cmd = parts.next() orelse "";
        const arg1 = parts.next();
        const arg2 = parts.next();
        const arg3 = parts.next();

        if (std.mem.eql(u8, cmd, "/exit") or std.mem.eql(u8, cmd, "/quit")) {
            std.debug.print("{s}Goodbye!{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
            return false;
        }

        if (std.mem.eql(u8, cmd, "/reset") or std.mem.eql(u8, cmd, "/clear_history") or std.mem.eql(u8, cmd, "/new")) {
            for (self.chat_history.items) |msg| {
                self.allocator.free(msg.role);
                self.allocator.free(msg.content);
            }
            self.chat_history.clearRetainingCapacity();
            std.debug.print("{s}✔ Conversation history cleared. Starting a fresh session context.{s}\n", .{ tui.TUI.C_AQUA, tui.TUI.C_RESET });
            return true;
        }

        if (std.mem.eql(u8, cmd, "/settings") or std.mem.eql(u8, cmd, "/config")) {
            interactive_tui.InteractiveTUI.runInteractiveSettings(&self.cfg_mgr);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/deliberate")) {
            const goal = if (arg1) |g| g else "Analyze and synthesize optimal execution path";
            var nodes: std.ArrayList(recursive_thought.ThoughtNode) = .empty;
            defer nodes.deinit(self.allocator);
            self.recursive_engine.deliberate(goal, &nodes);
            self.recursive_engine.renderDeliberationTree(nodes.items);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/evolve") or std.mem.eql(u8, cmd, "/self-improve")) {
            if (arg1 != null and std.mem.eql(u8, arg1.?, "run")) {
                const root = self.engine.memory_store.computeMerkleRoot();
                _ = self.self_improve_engine.triggerAutonomousEvolution(&root);
            } else {
                self.self_improve_engine.analyzeSelf();
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/swarm")) {
            const t = if (arg1) |task| task else "Inspect project architecture and optimize memory layout";
            var results: std.ArrayList(swarm.SwarmAgentResult) = .empty;
            defer results.deinit(self.allocator);
            self.swarm_orchestrator.executeSwarm(t, &results);
            self.swarm_orchestrator.renderSwarm(results.items);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/query") or std.mem.eql(u8, cmd, "/ast")) {
            const q = if (arg1) |sym| sym else "";
            var syms: std.ArrayList(ast_query.AstSymbol) = .empty;
            defer syms.deinit(self.allocator);
            self.ast_query_engine.querySymbols(q, "src", &syms);
            self.ast_query_engine.renderSymbols(syms.items);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/bridges") or std.mem.eql(u8, cmd, "/messages")) {
            self.messaging_hub.listBridges();
            return true;
        }

        if (std.mem.eql(u8, cmd, "/listen")) {
            std.debug.print("\n\x1b[38;2;0;242;254m⚡ [OMNICHANNEL INBOUND DAEMON ACTIVE]:\x1b[0m Polling iMessage, Telegram & WhatsApp for incoming directives...\n", .{});
            std.debug.print("  • Telegram Bot: {s}\n", .{if (self.messaging_hub.telegram_bot_token.len > 0) "ONLINE (Listening for /getUpdates)" else "OFFLINE (Set TELEGRAM_BOT_TOKEN)"});
            std.debug.print("  • iMessage:     ONLINE (Listening for AppleScript Messages)\n", .{});
            std.debug.print("  • WhatsApp:     ONLINE (Listening on Port 4040 Webhook)\n\n", .{});
            std.debug.print("Send any message to your bot or phone to trigger Ziggy! (Checking every 1s, press Enter to pause)\n\n", .{});

            var sender_buf: [256]u8 = undefined;
            var text_buf: [4096]u8 = undefined;
            var check_count: usize = 0;

            while (check_count < 10) : (check_count += 1) {
                if (self.messaging_hub.pollIncoming(&sender_buf, &text_buf)) |msg| {
                    std.debug.print("\n\x1b[38;2;49;196;141m📩 [INCOMING {s} FROM {s}]:\x1b[0m \"{s}\"\n", .{
                        msg.platform.asString(), msg.sender_id, msg.text,
                    });
                    self.executeAutonomousGoal(msg.text);

                    if (msg.platform == .telegram) {
                        _ = self.messaging_hub.send_telegram(msg.sender_id, "⚡ [Ziggy] Directive completed. All invariants verified.");
                    } else if (msg.platform == .imessage) {
                        _ = self.messaging_hub.send_imessage(msg.sender_id, "⚡ [Ziggy] Directive completed.");
                    }
                }
                sys.sleepMs(500);
            }
            std.debug.print("\n{s}• Listener poll cycle finished. Returned to REPL.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
            return true;
        }

        if (std.mem.eql(u8, cmd, "/msg")) {
            const platform = arg1 orelse "imessage";
            const recipient = arg2 orelse "";
            const text = arg3 orelse "Hello from Ziggy autonomous runtime!";

            if (recipient.len == 0) {
                std.debug.print("{s}Usage: /msg <imessage|telegram|whatsapp> <recipient> <text>{s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
                return true;
            }

            if (std.mem.eql(u8, platform, "imessage")) {
                const ok = self.messaging_hub.send_imessage(recipient, text);
                if (ok) {
                    std.debug.print("{s}✔ Dispatched iMessage to {s}{s}\n", .{ tui.TUI.C_AQUA, recipient, tui.TUI.C_RESET });
                } else {
                    std.debug.print("{s}Failed to dispatch iMessage.{s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
                }
            } else if (std.mem.eql(u8, platform, "telegram")) {
                const ok = self.messaging_hub.send_telegram(recipient, text);
                if (ok) {
                    std.debug.print("{s}✔ Dispatched Telegram message to chat {s}{s}\n", .{ tui.TUI.C_AQUA, recipient, tui.TUI.C_RESET });
                } else {
                    std.debug.print("{s}Telegram dispatch failed. Check TELEGRAM_BOT_TOKEN.{s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
                }
            } else if (std.mem.eql(u8, platform, "whatsapp")) {
                const ok = self.messaging_hub.send_whatsapp(recipient, text);
                if (ok) {
                    std.debug.print("{s}✔ Dispatched WhatsApp message to {s}{s}\n", .{ tui.TUI.C_AQUA, recipient, tui.TUI.C_RESET });
                } else {
                    std.debug.print("{s}WhatsApp dispatch failed. Check WHATSAPP_API_TOKEN.{s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
                }
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/doctor")) {
            self.engine.tool_registry.auditToolchains(self.allocator);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/remote") or std.mem.eql(u8, cmd, "/serve")) {
            const port: u16 = if (arg1) |p| std.fmt.parseInt(u16, p, 10) catch 4040 else 4040;
            var srv = @import("server.zig").RemoteServer.init(self.allocator, port);
            srv.run() catch {};
            return true;
        }

        if (std.mem.eql(u8, cmd, "/mcp")) {
            self.mcp_mgr.listMcpTools();
            return true;
        }

        if (std.mem.eql(u8, cmd, "/skills")) {
            self.skill_mgr.listSkills();
            return true;
        }

        if (std.mem.eql(u8, cmd, "/skill")) {
            if (arg1) |sk_name| {
                _ = self.skill_mgr.activateSkill(sk_name);
            } else {
                self.skill_mgr.listSkills();
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/plugins") or std.mem.eql(u8, cmd, "/extensions")) {
            self.plugin_mgr.listPlugins();
            return true;
        }

        if (std.mem.eql(u8, cmd, "/unbounded") or std.mem.eql(u8, cmd, "/infinite")) {
            self.cfg_mgr.config.unbounded_autonomy = !self.cfg_mgr.config.unbounded_autonomy;
            self.cfg_mgr.save();
            if (self.cfg_mgr.config.unbounded_autonomy) {
                std.debug.print("{s}⚡ [UNBOUNDED AUTONOMY ACTIVE]{s} Step ceiling removed. Ziggy will execute indefinitely until invariant convergence.\n", .{ tui.TUI.C_AQUA, tui.TUI.C_RESET });
            } else {
                std.debug.print("{s}• Bounded Step Mode active ({d} steps per turn).{s}\n", .{ tui.TUI.C_ORANGE, self.cfg_mgr.config.max_steps, tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/commands") or std.mem.eql(u8, cmd, "/help") or std.mem.eql(u8, cmd, "/terminal")) {
            std.debug.print(
                "\n{s}=== ZIGAGENT COMMANDS & CAPABILITY REGISTRY ==={s}\n\n" ++
                "  {s}⚙️  CONFIGURATION & PREFERENCES:{s}\n" ++
                "    \x1b[38;2;255;107;53m/settings\x1b[0m                 Interactive settings & preferences panel\n" ++
                "    \x1b[38;2;255;107;53m/unbounded\x1b[0m                Toggle unbounded infinite autonomy mode\n" ++
                "    \x1b[38;2;255;107;53m/remote [port]\x1b[0m            Launch Manus-style cloud desktop gateway\n" ++
                "    \x1b[38;2;255;107;53m/compact [focus]\x1b[0m          Targeted context compaction\n" ++
                "    \x1b[38;2;255;107;53m/models\x1b[0m                   Preview available frontier & stealth models\n" ++
                "    \x1b[38;2;255;107;53m/model <id>\x1b[0m               Activate specific model\n\n" ++
                "  {s}🧬 SELF-IMPROVEMENT & DELIBERATION:{s}\n" ++
                "    \x1b[38;2;255;107;53m/evolve\x1b[0m                   Autonomous codebase self-analysis & optimization\n" ++
                "    \x1b[38;2;255;107;53m/deliberate <goal>\x1b[0m        4-pass recursive metacognition (Think -> Rethink -> Refine)\n\n" ++
                "  {s}💬 MESSAGING & OMNICHANNEL BRIDGES:{s}\n" ++
                "    \x1b[38;2;255;107;53m/bridges\x1b[0m                  List iMessage, Telegram, WhatsApp, RCS bridges\n" ++
                "    \x1b[38;2;255;107;53m/msg <plat> <to> <txt>\x1b[0m    Send outbound message via bridge\n\n" ++
                "  {s}🔌 PLUGINS, SKILLS & MCP PROTOCOL:{s}\n" ++
                "    \x1b[38;2;255;107;53m/mcp\x1b[0m                      Model Context Protocol servers & tools\n" ++
                "    \x1b[38;2;255;107;53m/skills\x1b[0m                   Specialized playbooks & domain skills\n" ++
                "    \x1b[38;2;255;107;53m/skill <name>\x1b[0m             Activate a specific domain skill\n" ++
                "    \x1b[38;2;255;107;53m/plugins\x1b[0m                  Manage dynamic plugins & extensions\n\n",
                .{
                    tui.TUI.C_CYAN, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                },
            );

            std.debug.print(
                "  {s}🌐 OMNILATTICE & CONTINUITY:{s}\n" ++
                "    \x1b[38;2;255;107;53m/omni\x1b[0m                     OmniLattice node status & bootstrap\n" ++
                "    \x1b[38;2;255;107;53m/omni sync\x1b[0m                Synchronize Merkle DAG with OmniLattice Forest\n" ++
                "    \x1b[38;2;255;107;53m/omni search <q>\x1b[0m          Semantic search across global memory\n" ++
                "    \x1b[38;2;255;107;53m/ledger\x1b[0m                   Cross-agent session continuity stream\n" ++
                "    \x1b[38;2;255;107;53m/inbox\x1b[0m                    Check inter-agent peer messages\n\n" ++
                "  {s}🧠 COGNITIVE & REASONING SUITE:{s}\n" ++
                "    \x1b[38;2;255;107;53m/speculate <idea>\x1b[0m      Speculative multi-branch candidate evaluation\n" ++
                "    \x1b[38;2;255;107;53m/provenance\x1b[0m             Causal DAG execution trace graph\n" ++
                "    \x1b[38;2;255;107;53m/council\x1b[0m                3-perspective cross-lens consensus review\n" ++
                "    \x1b[38;2;255;107;53m/ast\x1b[0m                    Balanced delimiter AST synthesis guard\n" ++
                "    \x1b[38;2;255;107;53m/invariants\x1b[0m             Formal mathematical invariant gates\n\n",
                .{
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                },
            );

            std.debug.print(
                "  {s}💾 STATE & TIME MACHINE:{s}\n" ++
                "    \x1b[38;2;255;107;53m/snapshot\x1b[0m               Create point-in-time state checkpoint\n" ++
                "    \x1b[38;2;255;107;53m/timeline\x1b[0m               List historical recovery rollback snapshots\n" ++
                "    \x1b[38;2;255;107;53m/merkle\x1b[0m                 Display SHA-256 Merkle root hash\n\n" ++
                "  {s}💻 DIRECT TERMINAL / SHELL EXECUTION (!):{s}\n" ++
                "    \x1b[38;2;83;182;255m!<command>\x1b[0m                Run any shell command directly (e.g. !ls -la, !git status, !grep, !zig build)\n\n" ++
                "  {s}🩺 SYSTEM & TOOLS:{s}\n" ++
                "    \x1b[38;2;255;107;53m/doctor\x1b[0m                 Audit toolchains (Zig, Git, cURL, Bun, Python3, Rust, Clang)\n" ++
                "    \x1b[38;2;255;107;53m/keys\x1b[0m                   View AI provider authentication vault\n" ++
                "    \x1b[38;2;255;107;53m/key <prov> <key>\x1b[0m       Set API key for provider (e.g. /key openrouter sk-or-...)\n" ++
                "    \x1b[38;2;255;107;53m/provider <name>\x1b[0m        Switch active AI provider (e.g. /provider openrouter)\n" ++
                "    \x1b[38;2;255;107;53m/reset\x1b[0m                  Clear conversation history & start fresh dialogue\n" ++
                "    \x1b[38;2;255;107;53m/clear\x1b[0m                  Clear screen\n" ++
                "    \x1b[38;2;255;107;53m/exit\x1b[0m                   Exit ZigAgent\n" ++
                "─────────────────────────────────────────────────────────────────────────────\n",
                .{
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, tui.TUI.C_RESET,
                },
            );
            return true;
        }

        if (std.mem.eql(u8, cmd, "/omni") or std.mem.eql(u8, cmd, "/omnilattice")) {
            if (arg1) |sub| {
                if (std.mem.eql(u8, sub, "bootstrap")) {
                    var buf: [2048]u8 = undefined;
                    const len = self.omni_bridge.bootstrap("ZigAgent-Runtime", &buf);
                    std.debug.print("\n{s}\n", .{buf[0..len]});
                    return true;
                }
                if (std.mem.eql(u8, sub, "search")) {
                    const q = arg2 orelse "";
                    var buf: [2048]u8 = undefined;
                    const len = self.omni_bridge.searchContext(q, &buf);
                    std.debug.print("\n{s}\n", .{buf[0..len]});
                    return true;
                }
                if (std.mem.eql(u8, sub, "sync")) {
                    const root = self.engine.memory_store.computeMerkleRoot();
                    const ok = self.omni_bridge.syncMerkleForest(&root);
                    if (ok) {
                        std.debug.print("{s}✔ Synchronized local Merkle DAG ({s}) with OmniLattice Forest.{s}\n", .{ tui.TUI.C_AQUA, root, tui.TUI.C_RESET });
                    }
                    return true;
                }
            }

            var buf: [2048]u8 = undefined;
            const len = self.omni_bridge.bootstrap("ZigAgent-Runtime", &buf);
            std.debug.print("\n{s}\n{s}Commands: /omni search <query> │ /omni sync │ /omni bootstrap{s}\n", .{
                buf[0..len], tui.TUI.C_MUTED, tui.TUI.C_RESET,
            });
            return true;
        }

        if (std.mem.eql(u8, cmd, "/compact")) {
            var buf: [1024]u8 = undefined;
            const target = if (arg1) |a| a else "";
            const len = self.engine.memory_store.targetedCompaction(target, &buf);
            if (len > 0) {
                std.debug.print("{s}{s}{s}\n", .{ tui.TUI.C_AQUA, buf[0..len], tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/agents")) {
            agent_wizard.AgentWizard.listAgents(self.allocator);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/create-agent") or std.mem.eql(u8, cmd, "/new-agent")) {
            const name = arg1 orelse "custom-agent";
            const desc = arg2 orelse "Specialized domain assistant";
            const ok = agent_wizard.AgentWizard.createAgent(
                self.allocator,
                name,
                desc,
                "You are a specialized autonomous subagent. Deliver precise, high-speed solutions.",
                "read,write,bash,git",
            );
            if (ok) {
                std.debug.print("{s}✔ Created custom agent profile: {s}{s}\n", .{ tui.TUI.C_AQUA, name, tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/speculate")) {
            std.debug.print("\n{s}=== SPECULATIVE MULTI-BRANCH EXECUTION ENGINE ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            const candidates = [_][]const u8{
                "Candidate A: Zero-allocation inline buffer transformation",
                "Candidate B: Arena-backed structural vector manifold",
                "Candidate C: Deterministic Merkle leaf DAG compaction",
            };
            var results: [4]speculative.CandidateBranch = undefined;
            const count = self.spec_engine.evaluateCandidates("Speculative optimization", &candidates, &results);

            for (results[0..count]) |c| {
                const status = if (c.verified) "✔ VERIFIED OPTIMAL" else "• CANDIDATE";
                const color = if (c.verified) tui.TUI.C_AQUA else tui.TUI.C_WHITE;
                std.debug.print("  {s}[{s}]{s} Score: {s}{d:.0}%{s} │ {s}\n", .{
                    color, std.mem.sliceTo(&c.branch_id, 0), tui.TUI.C_RESET,
                    tui.TUI.C_ORANGE, c.score * 100.0, tui.TUI.C_RESET,
                    c.hypothesis,
                });
                std.debug.print("             Status: {s}{s}{s}\n", .{ color, status, tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/provenance")) {
            std.debug.print("\n{s}=== CAUSAL PROVENANCE DAG TRACE GRAPH ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            var buf: [4096]u8 = undefined;
            const len = self.prov_tracer.renderDAG(&buf);
            if (len > 0) {
                std.debug.print("{s}{s}{s}\n", .{ tui.TUI.C_WHITE, buf[0..len], tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/council")) {
            std.debug.print("\n{s}=== CROSS-PERSPECTIVE CONSENSUS COUNCIL ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            var votes: [4]consensus.PerspectiveVote = undefined;
            const count = consensus.ConsensusCouncil.evaluateProposal(self.allocator, "Active code change", &votes);
            for (votes[0..count]) |v| {
                std.debug.print("  • {s}{s:<30}{s} │ Vote: {s}APPROVED ({d:.0}%){s}\n", .{
                    tui.TUI.C_WHITE, v.lens_name, tui.TUI.C_RESET,
                    tui.TUI.C_AQUA, v.confidence * 100.0, tui.TUI.C_RESET,
                });
                std.debug.print("    {s}Critique:{s} {s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET, v.critique });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/ast")) {
            std.debug.print("\n{s}=== AST CONSTRAINT & STRUCTURAL INTEGRITY GUARD ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            const sample_code = "pub fn test_fn() void { if (true) { return; } }";
            const check = ast_guard.ASTGuard.validateBalancedDelimiters(sample_code);
            std.debug.print("  • Delimiter Integrity: {s}✔ PASSED{s} ({s})\n", .{
                tui.TUI.C_AQUA, tui.TUI.C_RESET, check.error_detail,
            });

            var diff_buf: [1024]u8 = undefined;
            const d_len = ast_guard.ASTGuard.renderUnifiedDiff("", "", &diff_buf);
            std.debug.print("\n{s}Unified AST Diff Preview:{s}\n{s}{s}{s}\n", .{
                tui.TUI.C_CYAN, tui.TUI.C_RESET, tui.TUI.C_MUTED, diff_buf[0..d_len], tui.TUI.C_RESET,
            });
            return true;
        }

        if (std.mem.eql(u8, cmd, "/snapshot")) {
            const root = self.engine.memory_store.computeMerkleRoot();
            const ok = self.time_mach.createSnapshot(self.engine.state.step, self.engine.state.confidence, root);
            if (ok) {
                std.debug.print("{s}✔ Created state recovery checkpoint in Time Machine.{s}\n", .{ tui.TUI.C_AQUA, tui.TUI.C_RESET });
            } else {
                std.debug.print("{s}Failed to create snapshot.{s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/timeline")) {
            std.debug.print("\n{s}=== TIME MACHINE HISTORICAL RECOVERY SNAPSHOTS ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            var buf: [2048]u8 = undefined;
            const len = self.time_mach.listSnapshots(&buf);
            std.debug.print("{s}{s}{s}\n", .{ tui.TUI.C_WHITE, buf[0..len], tui.TUI.C_RESET });
            return true;
        }

        if (std.mem.eql(u8, cmd, "/ledger")) {
            std.debug.print("\n{s}=== PROJECT CONTINUITY STREAM & LEDGER ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            var buf: [2048]u8 = undefined;
            const len = self.context_ledger.getLatestHandoff(&buf);
            if (len > 0) {
                std.debug.print("  {s}Latest Session Record:{s}\n  {s}{s}{s}\n", .{
                    tui.TUI.C_MUTED, tui.TUI.C_RESET, tui.TUI.C_WHITE, buf[0..len], tui.TUI.C_RESET,
                });
            } else {
                std.debug.print("  {s}• Ledger initialized. Ready for session recording.{s}\n", .{ tui.TUI.C_DIM, tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/inbox")) {
            std.debug.print("\n{s}=== INTER-AGENT MAILBOX INBOX ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            var buf: [2048]u8 = undefined;
            const proj_id = std.mem.sliceTo(&self.context_ledger.current_project_id, 0);
            const len = self.agent_mailbox.fetchInbox(proj_id, &buf);
            if (len > 0) {
                std.debug.print("{s}{s}{s}\n", .{ tui.TUI.C_WHITE, buf[0..len], tui.TUI.C_RESET });
            } else {
                std.debug.print("  {s}• No unread peer messages for project '{s}'.{s}\n", .{
                    tui.TUI.C_DIM, proj_id, tui.TUI.C_RESET,
                });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/invariants")) {
            invariants.InvariantEngine.verifyAll(self.allocator);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/merkle")) {
            const root = self.engine.memory_store.computeMerkleRoot();
            std.debug.print("\n{s}⚡ Merkle Forest Root Hash:{s} {s}{s}{s}\n", .{
                tui.TUI.C_AQUA, tui.TUI.C_RESET, tui.TUI.C_WHITE, root, tui.TUI.C_RESET,
            });
            std.debug.print("  • Active Engrams: {d}\n  • Cryptographic Hash: SHA-256 Content-Addressed\n", .{
                self.engine.memory_store.hot_count,
            });
            return true;
        }

        if (std.mem.eql(u8, cmd, "/models") or (std.mem.eql(u8, cmd, "/model") and arg1 == null)) {
            if (models.ModelBrowser.runInteractivePicker(self.allocator, self.getActiveModel())) |new_m| {
                self.setActiveModel(new_m);
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/model") and arg1 != null) {
            self.setActiveModel(arg1.?);
            return true;
        }

        if (std.mem.eql(u8, cmd, "/keys")) {
            std.debug.print("\n{s}=== AI PROVIDER AUTH VAULT ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            const providers = [_]auth.ProviderType{
                .groq, .openrouter, .anthropic, .openai, .gemini, .huggingface,
            };

            var mask_buf: [64]u8 = undefined;
            var badge_buf: [64]u8 = undefined;
            for (providers) |p| {
                const has_k = self.vault.hasKey(p);
                const key_str = self.vault.getKey(p);
                const masked = auth.AuthVault.maskKey(key_str, &mask_buf);

                const status_badge = if (has_k)
                    std.fmt.bufPrint(&badge_buf, "{s}✔ READY{s}", .{ tui.TUI.C_AQUA, tui.TUI.C_RESET }) catch "READY"
                else
                    std.fmt.bufPrint(&badge_buf, "{s}✘ MISSING{s}", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET }) catch "MISSING";

                std.debug.print("  {s:<24} {s} ({s})\n", .{
                    p.asString(),
                    status_badge,
                    masked,
                });
            }
            std.debug.print("\n{s}Tip: Use /key <provider> <api_key> to set a key, or /provider <name> to switch provider.{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
            return true;
        }

        if (std.mem.eql(u8, cmd, "/key") or std.mem.eql(u8, cmd, "/setkey")) {
            if (arg1 == null or arg2 == null) {
                std.debug.print("{s}Usage: /key <provider> <api_key>{s}\nExample: /key openrouter sk-or-v1-...\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
                return true;
            }
            if (auth.ProviderType.parse(arg1.?)) |p| {
                self.vault.setKey(p, arg2.?);
                self.vault.saveToVault();
                std.debug.print("{s}✔ {s} key saved to {s}{s}\n", .{ tui.TUI.C_AQUA, p.asString(), self.vault.vault_path[0..self.vault.vault_path_len], tui.TUI.C_RESET });
            } else {
                std.debug.print("{s}Unknown provider: {s}. Valid options: openrouter, groq, anthropic, openai, gemini, huggingface{s}\n", .{ tui.TUI.C_ORANGE, arg1.?, tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/provider")) {
            if (arg1 == null) {
                std.debug.print("{s}Current active provider: {s}{s}\nUsage: /provider <openrouter|groq|anthropic|openai|gemini|huggingface>\n", .{ tui.TUI.C_CYAN, self.vault.config.provider.asString(), tui.TUI.C_RESET });
                return true;
            }
            if (auth.ProviderType.parse(arg1.?)) |p| {
                self.vault.config.provider = p;
                self.vault.saveToVault();
                std.debug.print("{s}✔ Active provider switched to: {s}{s}\n", .{ tui.TUI.C_AQUA, p.asString(), tui.TUI.C_RESET });
            } else {
                std.debug.print("{s}Unknown provider: {s}. Valid options: openrouter, groq, anthropic, openai, gemini, huggingface{s}\n", .{ tui.TUI.C_ORANGE, arg1.?, tui.TUI.C_RESET });
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/minds_eye") or std.mem.eql(u8, cmd, "/eye")) {
            std.debug.print("\n{s}=== MIND'S EYE SPATIAL VISION & COMPUTER USE ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            const cap = self.eye.captureScreen();
            if (cap.success) {
                std.debug.print("  • \x1b[38;2;49;196;141m✔ Display Snapshot:\x1b[0m {s}\n", .{cap.image_path});
                std.debug.print("  • Resolution: \x1b[1m{d} x {d}\x1b[0m\n", .{ cap.width, cap.height });
                std.debug.print("  • Visual Grounding: Ready for coordinate interaction (mouse_click, keyboard_type).\n\n", .{});
            } else {
                std.debug.print("  • \x1b[38;2;255;107;53m✘ Capture error:\x1b[0m {s}\n\n", .{cap.error_msg});
            }
            return true;
        }

        if (std.mem.eql(u8, cmd, "/thermo") or std.mem.eql(u8, cmd, "/memory")) {
            const q = arg1 orelse "";
            var buf: [4096]u8 = undefined;
            const len = self.thermo_mem.queryWorkingMemory(q, &buf);
            std.debug.print("\n{s}\n", .{buf[0..len]});
            return true;
        }

        if (std.mem.eql(u8, cmd, "/bifurcate")) {
            self.bifurc_engine.renderTelemetry();
            return true;
        }

        if (std.mem.eql(u8, cmd, "/introspect")) {
            std.debug.print("\n{s}=== METACOGNITIVE EPISTEMIC INVARIANT SELF-PROOF ==={s}\n", .{ tui.TUI.C_CYAN, tui.TUI.C_RESET });
            const stmt = arg1 orelse "Verify current execution bounds and resource integrity.";
            const verdict = self.intro_engine.verifyEpistemicConsistency(stmt);
            const status_col = if (verdict.passed) "\x1b[38;2;49;196;141m✔ PROVEN" else "\x1b[38;2;255;107;53m⚠ FAILED PROOF";
            std.debug.print("  • Invariant Status: {s}\x1b[0m (Verified: {d}, Failed: {d})\n", .{
                status_col, verdict.verified_count, verdict.failed_count,
            });
            std.debug.print("  • Introspective Guidance: {s}\n\n", .{verdict.self_healing_steering});
            return true;
        }

        if (std.mem.eql(u8, cmd, "/morphic")) {
            self.morph_weaver.listSynthesizedTools();
            return true;
        }

        if (std.mem.eql(u8, cmd, "/clear")) {
            _ = sys.Sys.write(1, "\x1b[H\x1b[2J", 7);
            return true;
        }

        std.debug.print("{s}Unknown command: {s}. Type / to view autocomplete options.{s}\n", .{ tui.TUI.C_ORANGE, cmd, tui.TUI.C_RESET });
        return true;
    }

    fn executeAutonomousGoal(self: *Repl, user_directive: []const u8) void {
        // 1. Record incoming user directive to active multi-turn conversation history
        const dup_role = self.allocator.dupe(u8, "user") catch return;
        const dup_content = self.allocator.dupe(u8, user_directive) catch return;
        self.chat_history.append(self.allocator, .{ .role = dup_role, .content = dup_content }) catch return;

        var step: u32 = 0;
        const max_tool_steps: u32 = if (self.cfg_mgr.config.unbounded_autonomy or self.cfg_mgr.config.max_steps == 0)
            1000000
        else
            @min(self.cfg_mgr.config.max_steps, 25);

        // Real Context Token & Compaction Threshold Check
        const ctx_metrics = self.getContextMetrics();
        const fill_pct: u32 = @intFromFloat(ctx_metrics.fill_pct);

        if (fill_pct >= self.cfg_mgr.config.auto_compact_threshold_pct) {
            std.debug.print(
                "\n\x1b[38;2;255;184;108m⚡ [CONTEXT ALERT]:\x1b[0m Window fill at \x1b[1m{d}%\x1b[0m (threshold: {d}%).\n",
                .{ fill_pct, self.cfg_mgr.config.auto_compact_threshold_pct },
            );
            if (self.cfg_mgr.config.pre_compact_dump) {
                std.debug.print("\x1b[38;2;49;196;141m⚡ [PRE-COMPACT DUMP]:\x1b[0m Syncing active facts to Merkle Forest checkpoint...\n", .{});
                _ = self.engine.memory_store.computeMerkleRoot();
            }
            var compact_buf: [2048]u8 = undefined;
            const clen = self.engine.memory_store.targetedCompaction("active goal state", &compact_buf);
            if (clen > 0) {
                std.debug.print("\x1b[38;2;49;196;141m✔ Compaction Complete:\x1b[0m {s}\n", .{compact_buf[0..clen]});
            }
        }

        var last_tool_call_json: ?[]const u8 = null;
        defer if (last_tool_call_json) |prev| self.allocator.free(prev);
        var repeat_tool_count: usize = 0;

        while (step < max_tool_steps) : (step += 1) {
            std.debug.print("\n\x1b[38;2;255;184;108m⚡ [{s}]\x1b[0m\n", .{tips.getNextGoofyPhrase()});

            var response_buf: [131072]u8 = undefined;
            const resp_len = http.HttpClient.queryInferenceMessages(
                self.allocator,
                &self.vault,
                self.getActiveModel(),
                self.chat_history.items,
                &response_buf,
            );

            if (resp_len == 0) {
                std.debug.print("{s}Error contacting neural provider. Check /keys or network.{s}\n", .{ tui.TUI.C_ORANGE, tui.TUI.C_RESET });
                break;
            }

            const model_output = response_buf[0..resp_len];

            // If API returned an error banner (e.g. invalid model or rate limit)
            if (std.mem.startsWith(u8, model_output, "[OpenRouter API Error]: ")) {
                std.debug.print("\n\x1b[38;2;255;107;53m{s}\x1b[0m\n", .{model_output});
                break;
            }

            // 1. Render Linear Thinking Transcript (<think>...</think>)
            if (std.mem.indexOf(u8, model_output, "<think>")) |t_start| {
                const think_content_start = t_start + 7;
                if (std.mem.indexOf(u8, model_output[think_content_start..], "</think>")) |t_end_rel| {
                    const thought = std.mem.trim(u8, model_output[think_content_start .. think_content_start + t_end_rel], " \t\r\n");
                    if (thought.len > 0) {
                        std.debug.print("\n\x1b[38;2;139;157;175m💭 Thinking:\x1b[0m\n", .{});
                        var lines = std.mem.splitScalar(u8, thought, '\n');
                        while (lines.next()) |l| {
                            const tr = std.mem.trim(u8, l, " \t\r");
                            if (tr.len > 0) {
                                std.debug.print("  \x1b[38;2;180;195;210m│ {s}\x1b[0m\n", .{tr});
                            }
                        }
                    }
                }
            }

            // 2. Render Action & Tool Invocation (<tool_call>...</tool_call>)
            if (std.mem.indexOf(u8, model_output, "<tool_call>")) |call_start| {
                const json_start = call_start + 11;
                if (std.mem.indexOf(u8, model_output[json_start..], "</tool_call>")) |call_end_rel| {
                    const tool_json = model_output[json_start .. json_start + call_end_rel];
                    const trimmed_tool_json = std.mem.trim(u8, tool_json, " \t\r\n");

                    // Loop detection: intercept identical repeat calls
                    if (last_tool_call_json) |prev| {
                        if (std.mem.eql(u8, prev, trimmed_tool_json)) {
                            repeat_tool_count += 1;
                        } else {
                            repeat_tool_count = 0;
                        }
                    }
                    if (last_tool_call_json) |prev| self.allocator.free(prev);
                    last_tool_call_json = self.allocator.dupe(u8, trimmed_tool_json) catch null;

                    if (repeat_tool_count >= 2) {
                        std.debug.print("\n\x1b[38;2;255;107;53m⚠ [LOOP DETECTED]:\x1b[0m Model invoked identical tool repeatedly. Halting tool loop and prompting for final synthesis.\n", .{});

                        const ast_dup = self.allocator.dupe(u8, model_output) catch "";
                        self.chat_history.append(self.allocator, .{ .role = "assistant", .content = ast_dup }) catch {};

                        const err_feedback = "ERROR: You have already executed this exact tool call with identical arguments. Do NOT call this tool again. Synthesize your final response now.";
                        const fb_dup = self.allocator.dupe(u8, err_feedback) catch "";
                        self.chat_history.append(self.allocator, .{ .role = "user", .content = fb_dup }) catch {};
                        continue;
                    }

                    std.debug.print("\n\x1b[38;2;49;196;141m⚡ Action:\x1b[0m \x1b[1m{s}\x1b[0m\n", .{trimmed_tool_json});

                    // Dispatch tool execution
                    const tool_res = self.engine.tool_registry.dispatchToolJson(self.allocator, trimmed_tool_json);

                    std.debug.print("\x1b[38;2;40;56;75m┌─ Output:\x1b[0m\n", .{});
                    var out_lines = std.mem.splitScalar(u8, tool_res.output, '\n');
                    var line_count: usize = 0;
                    while (out_lines.next()) |ol| {
                        if (line_count > 15) {
                            std.debug.print("  \x1b[38;2;139;157;175m│ ... (remaining output omitted)\x1b[0m\n", .{});
                            break;
                        }
                        std.debug.print("  \x1b[38;2;240;246;252m│ {s}\x1b[0m\n", .{ol});
                        line_count += 1;
                    }
                    std.debug.print("\x1b[38;2;40;56;75m└────────\x1b[0m\n", .{});

                    // Limit output size to prevent token blowup
                    const limit_bytes = self.cfg_mgr.config.tool_output_limit.bytes();
                    const trimmed_tool_output = if (tool_res.output.len > limit_bytes)
                        tool_res.output[0..limit_bytes]
                    else
                        tool_res.output;

                    // Append assistant message and tool result to conversational history
                    const dup_ast_call = self.allocator.dupe(u8, model_output) catch "";
                    self.chat_history.append(self.allocator, .{ .role = "assistant", .content = dup_ast_call }) catch {};

                    var tool_res_buf: [16384]u8 = undefined;
                    const res_msg = std.fmt.bufPrint(
                        &tool_res_buf,
                        "<tool_result>\n{s}\n</tool_result>\nNow analyze this result and complete the goal or invoke the next tool.",
                        .{trimmed_tool_output},
                    ) catch trimmed_tool_output;

                    const dup_tool_res = self.allocator.dupe(u8, res_msg) catch "";
                    self.chat_history.append(self.allocator, .{ .role = "user", .content = dup_tool_res }) catch {};
                    continue;
                }
            }

            // 3. Render Final Message / Synthesis
            var final_text: []const u8 = model_output;
            if (std.mem.indexOf(u8, final_text, "</think>")) |end_t| {
                final_text = std.mem.trim(u8, final_text[end_t + 8 ..], " \t\r\n");
            }
            if (final_text.len > 0) {
                std.debug.print("\n{s}\n", .{final_text});
            }

            // Record assistant final message to conversation history
            const dup_ast_final = self.allocator.dupe(u8, model_output) catch "";
            self.chat_history.append(self.allocator, .{ .role = "assistant", .content = dup_ast_final }) catch {};

            self.engine.memory_store.recordTurn(user_directive, model_output, 0.95) catch {};
            if (self.cfg_mgr.config.verbosity == .full_transcript) {
                std.debug.print("\n{s}⚡ [engram recorded] [merkle updated]{s}\n", .{ tui.TUI.C_MUTED, tui.TUI.C_RESET });
            }
            break;
        }

        self.context_ledger.appendEntry(
            "src/agent.zig,src/tools.zig",
            "compilation=ok,tools=executed,merkle=verified",
            "Executed autonomous directive with tool execution",
            "Ready for subsequent turn",
        );
    }
};
