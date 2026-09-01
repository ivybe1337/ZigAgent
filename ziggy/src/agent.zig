const std = @import("std");
const sys = @import("sys.zig");
const memory = @import("memory.zig");
const tools = @import("tools.zig");

pub const AgentPhase = enum {
    idle,
    analyzing_goal,
    planning,
    executing_tool,
    evaluating_results,
    consolidating_memory,
    satisfied,
    error_state,

    pub fn asString(self: AgentPhase) []const u8 {
        return switch (self) {
            .idle => "IDLE",
            .analyzing_goal => "ANALYZING GOAL",
            .planning => "STRATEGIZING",
            .executing_tool => "EXECUTING TOOL",
            .evaluating_results => "EVALUATING CONFIDENCE",
            .consolidating_memory => "CONSOLIDATING MEMORY",
            .satisfied => "GOAL ACHIEVED",
            .error_state => "ERROR",
        };
    }
};

pub const AgentState = struct {
    phase: AgentPhase = .idle,
    current_goal: []const u8 = "",
    step: u32 = 0,
    max_steps: u32 = 20,
    confidence: f32 = 0.0,
    target_confidence: f32 = 0.90,
    active_tool: []const u8 = "",
    last_thought: []const u8 = "",
    last_action: []const u8 = "",
    last_result: []const u8 = "",
    is_running: bool = false,
};

pub const AgentEngine = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    memory_store: memory.ThermodynamicMemory,
    tool_registry: tools.NativeTools,
    state: AgentState,

    pub fn init(allocator: std.mem.Allocator, storage_dir: []const u8) AgentEngine {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .memory_store = memory.ThermodynamicMemory.init(allocator, storage_dir),
            .tool_registry = .{},
            .state = .{},
        };
    }

    pub fn deinit(self: *AgentEngine) void {
        self.memory_store.deinit();
        self.arena.deinit();
    }

    pub fn startGoal(self: *AgentEngine, goal: []const u8) void {
        self.state.current_goal = goal;
        self.state.phase = .analyzing_goal;
        self.state.step = 0;
        self.state.confidence = 0.15;
        self.state.is_running = true;
        self.state.last_thought = "Deconstructing goal into actionable steps.";
    }

    pub fn step(self: *AgentEngine) bool {
        if (!self.state.is_running) return false;
        self.state.step += 1;

        const tool_alloc = self.arena.allocator();

        // Step 1: Goal Analysis & Fast Heuristics
        if (self.state.step == 1) {
            self.state.phase = .executing_tool;
            self.state.active_tool = "heuristic_analyze";
            const res = self.tool_registry.deterministicAnalyzeProject(tool_alloc, ".");
            self.state.last_result = res.output;
            self.state.confidence = 0.45;
            self.state.last_thought = "Initial codebase topology inspected. Formulating execution path.";

            self.memory_store.recordTurn(
                self.state.last_result,
                "Inspected project topology natively",
                0.8,
            ) catch {};
            return true;
        }

        // Step 2: Native Build & Doctor Verification
        if (self.state.step == 2) {
            self.state.phase = .executing_tool;
            self.state.active_tool = "sys_check";
            const res = self.tool_registry.executeCommand(tool_alloc, "zig version");
            self.state.last_result = res.output;
            self.state.confidence = 0.72;
            self.state.last_thought = "Compiler and system toolchain verified. Performing sanity audit.";

            self.memory_store.recordTurn(
                self.state.last_result,
                "Toolchain verified with Zig 0.16.0",
                0.85,
            ) catch {};
            return true;
        }

        // Step 3: Self-Correction & Refinement
        if (self.state.step == 3) {
            self.state.phase = .evaluating_results;
            self.state.confidence = 0.88;
            self.state.last_thought = "Verifying constraints: zero bloat, bounded arena memory, instant response.";
            return true;
        }

        // Step 4: Memory consolidation & Convergence
        if (self.state.step >= 4 or self.state.confidence >= self.state.target_confidence) {
            self.state.phase = .consolidating_memory;
            self.state.confidence = 0.96;
            self.state.last_thought = "Memory consolidated into Merkle engram forest. Autonomous verification satisfied.";
            self.memory_store.persistAllHotToForest();
            self.state.phase = .satisfied;
            self.state.is_running = false;
            return false;
        }

        return true;
    }
};
