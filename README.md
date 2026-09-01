# ⚡ ZigAgent (Ziggy)

> **Ultra-Fast, Native Autonomous AI Coding Agent & Hybrid Reasoning Engine in Pure Zig & Cocoa**

ZigAgent (**Ziggy**) is a high-performance autonomous agent written from scratch in native **Zig 0.16.0** and **Objective-C / Cocoa**. It features an unbounded multi-step ReAct tool loop, POSIX terminal engine, Merkle DAG epistemic memory, and live token-efficient context compaction.

---

## ✨ Features

- **🚀 Pure Native Zero-Lag Runtime**: Sub-millisecond startup, zero garbage collection latency, minimal memory footprint (< 5MB RAM).
- **⚡ Unbounded Autonomous Action Loop**: Executes multi-step actions continuously until formal invariant convergence (`/unbounded`).
- **🛑 Live `<ESC>` Interrupt & Steering**: Non-blocking POSIX terminal polling allows halting execution or injecting steering directives mid-flight.
- **💻 Direct Shell Engine (`!<command>`)**: Run shell commands natively without exiting the REPL (`!ls -la`, `!git status`, `!zig build`).
- **📊 Real-Time Context Fill HUD**: Graphical progress bar displaying token consumption, active workspace, model, and reasoning depth.
- **🧠 Thermodynamic Memory & Merkle Forest**: Cryptographically hashed SHA-256 engrams persist state across sessions with zero context degradation.
- **🌐 OmniLattice Mesh Integration**: Synchronizes causal DAGs and peer mailbox messages with global OmniLattice nodes.
- **🖥️ Native macOS Cocoa App**: Complete desktop GUI with chat stream, conversation archives, settings panel, and `/doctor` diagnostics.

---

## 🛠️ Installation & Building

### 1. Build CLI (`ziggy`)
```bash
cd ziggy
zig build -Doptimize=ReleaseFast

# Symlink to PATH (optional)
ln -sf $(pwd)/zig-out/bin/ziggy ~/.local/bin/ziggy
```

### 2. Build Native macOS App (`ZigAgent.app`)
```bash
cd app
clang -framework Cocoa -O3 src/main.m -o ZigAgent.app/Contents/MacOS/ZigAgent
open ZigAgent.app
```

---

## ⌨️ Command Reference

| Command | Description |
| :--- | :--- |
| `!<command>` | Execute any shell command directly (`!ls`, `!git diff`, `!bun test`) |
| `/settings` | Open interactive full-screen settings & preferences panel |
| `/unbounded` | Toggle infinite autonomy loop without step limits |
| `/commands` | Display categorized capability registry |
| `/doctor` | Run comprehensive system toolchains audit |
| `/compact` | Perform targeted semantic context compaction |
| `/models` | Preview available frontier and stealth AI models |
| `/omni sync` | Synchronize Merkle DAG with OmniLattice Forest |
| `/speculate` | Multi-branch candidate evaluation engine |
| `/ast` | Verify AST delimiter and structural syntax guards |
| `/snapshot` | Create point-in-time state checkpoint in Time Machine |

---

## 📜 License

MIT License © 2026 Joshua / ivybe1337
