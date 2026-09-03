const std = @import("std");

pub const ROTATING_TIPS = [_][]const u8{
    "Press TAB to autocomplete slash commands (/model, /keys, /reset) or prompt directives.",
    "Type !<cmd> to run any shell command directly (e.g. !git status, !ls -la).",
    "Type /key openrouter <key> to save your OpenRouter API key.",
    "Type /models to browse 20+ frontier models or /model for interactive selection.",
    "Paste logs or multi-line code freely; Ziggy supports bracketed paste without truncation.",
    "Type /reset to wipe the active conversation history and start a fresh turn.",
    "Run /doctor to audit your toolchains (Zig, Git, cURL, Bun, Python3, Clang).",
    "Run /minds_eye to capture your screen and enable computer use grounding.",
    "Run /deliberate for 4-pass recursive metacognitive deliberation on hard problems.",
    "Run /swarm to orchestrate 4 specialized agents in parallel.",
    "Run /snapshot to save a point-in-time state checkpoint to Time Machine.",
    "Type /settings to toggle streaming, sandbox mode, and compaction thresholds.",
};

pub const GOOFY_STATUS_PHRASES = [_][]const u8{
    "combobulating...",
    "shining the turtle...",
    "putting the in...",
    "fucking the duck...",
    "herding the quantum bits...",
    "consulting the elder council...",
    "reticulating splines...",
    "stirring the cyber broth...",
    "baking fresh tokens...",
    "percolating neural thoughts...",
    "polishing the merkle root...",
    "defragmenting the vibes...",
    "bribing the neural network...",
    "spinning up cerebral gears...",
    "aligning cosmic tensors...",
    "calibrating the flux capacitor...",
    "untangling syntactic spaghetti...",
};

var tip_index: usize = 0;
var goofy_index: usize = 0;

pub fn getNextTip() []const u8 {
    const tip = ROTATING_TIPS[tip_index % ROTATING_TIPS.len];
    tip_index += 1;
    return tip;
}

pub fn getNextGoofyPhrase() []const u8 {
    const phrase = GOOFY_STATUS_PHRASES[goofy_index % GOOFY_STATUS_PHRASES.len];
    goofy_index += 1;
    return phrase;
}
