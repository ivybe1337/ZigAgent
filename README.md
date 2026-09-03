# ⚡ ZigAgent (Ziggy)

> **Native Autonomous AI Coding Agent, REPL & Tool Runtime in Zig 0.16.0 & macOS Cocoa**

<p align="center">
  <img src="app/AppIcon.iconset/icon_512x512.png" width="130" alt="ZigAgent Icon" style="border-radius: 24px;" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Language-Zig_0.16.0-f7a41d?style=flat-square" alt="Zig 0.16.0" />
  <img src="https://img.shields.io/badge/GUI-Native_Cocoa_AppKit-00f2fe?style=flat-square" alt="macOS Cocoa" />
  <img src="https://img.shields.io/badge/Memory-Step_Arena_Allocation-31c48d?style=flat-square" alt="Zero GC" />
  <img src="https://img.shields.io/badge/Protocol-MCP_JSON--RPC_2.0-7928ca?style=flat-square" alt="MCP" />
  <img src="https://img.shields.io/badge/Providers-Groq_|_OpenRouter_|_Ollama-ff6b35?style=flat-square" alt="Providers" />
</p>

---

## 📌 Overview

**ZigAgent** (**Ziggy**) is a native autonomous AI coding assistant and agentic execution environment built with **Zig 0.16.0** and **Objective-C / Cocoa**. It provides a lightweight, deterministic alternative to Node.js and Python-based agent runtimes by compiling directly to a standalone native binary with sub-millisecond startup, deterministic arena memory management, and zero garbage-collection pauses.

ZigAgent features:
- **Interactive Terminal REPL**: Clean dual-divider prompt layout, full-color telemetry, and interactive arrow-key model selection.
- **Autonomous Tool Execution**: Native file reading, surgical file editing, directory indexing, code search, git operations, and shell command execution.
- **Neural Model Routing**: Direct Groq LPU inference for high-throughput reasoning models (`openai/gpt-oss-120b`, `qwen/qwen3.8-27b`), with universal OpenRouter and local Ollama failover.
- **Model Context Protocol (MCP)**: JSON-RPC 2.0 client for discovering and executing tools from external MCP servers.
- **Native macOS Desktop Studio**: Three-column workspace featuring real-time chat, an embedded WebKit browser, an editable code preview panel with markdown/HTML rendering, and an integrated shell terminal.

---

## 🚀 Technical Specifications

| Metric | ZigAgent (Ziggy) | Node.js / Python Agent Frameworks |
| :--- | :--- | :--- |
| **Binary Footprint** | **~750 KB** (ReleaseFast standalone) | 250 MB – 1.2 GB (Runtime + node_modules/venv) |
| **Process Startup** | **< 3 ms** | 1,500 ms – 4,000 ms |
| **Idle Memory (RAM)**| **< 6 MB** | 200 MB – 600 MB |
| **Memory Lifecycle** | **Step-Bounded Arena Recycling** | Garbage Collection (unpredictable latency) |
| **Inference Routing** | **Groq LPU (300+ tps) + OpenRouter + Ollama** | Provider-locked or dynamic SDK wrappers |
| **Tool Execution** | **Native POSIX Pipes & System Calls** | Heavy IPC bridges or subprocess abstraction |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ZIGAGENT ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  [User Interfaces]                                                          │
│  • Interactive Terminal REPL:          ziggy                                │
│  • Native macOS Cocoa Studio:          ZigAgent.app                         │
│  • Local HTTP / WebSocket Canvas:      Port 4040 Web Server                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  [Execution & Reasoning Engine]                                             │
│  • Autonomous ReAct Action Loop:       Tool execution -> Result feedback    │
│  • Multi-Pass Deliberation Pipeline:   Hypothesis -> Critique -> Synthesis  │
│  • AST Syntax & Delimiter Guard:       Structural balanced delimiter checks │
│  • 3-Lens Consensus Council:           Security / Performance / Architecture│
├─────────────────────────────────────────────────────────────────────────────┤
│  [Protocols & Extensions]                                                   │
│  • Model Context Protocol (MCP):       JSON-RPC 2.0 stdio server client     │
│  • Specialized Skill System:           Dynamic SKILL.md playbook loader     │
│  • Messaging Gateways:                 Telegram Bot, iMessage (osascript)   │
├─────────────────────────────────────────────────────────────────────────────┤
│  [State & Continuity]                                                       │
│  • L1 Memory Ring Buffer:              Hot in-memory context tracking       │
│  • L3 Merkle Root DAG:                 SHA-256 state verification           │
│  • Context Ledger:                     Append-only JSONL continuity records │
│  • Time Machine Snapshots:             Point-in-time workspace rollbacks    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Installation & Building

### Prerequisites
- **Zig 0.16.0** (or modern master)
- **Apple Clang** (for compiling `ZigAgent.app` on macOS)
- **Git** and **cURL**

### 1. Build the CLI Binary
```bash
cd ziggy
zig build -Doptimize=ReleaseFast
cp zig-out/bin/ziggy ~/.local/bin/ziggy
```

### 2. Build the Native macOS Desktop App
```bash
cd app
clang -framework Cocoa -framework WebKit -O3 src/main.m -o ZigAgent.app/Contents/MacOS/ZigAgent
open ZigAgent.app
```

---

## 💻 CLI Usage

Launch the interactive REPL:
```bash
ziggy
```

### Interactive Slash Commands
- `/models`: Open the interactive OpenRouter-style scrollable model browser (`↑`/`↓`/`j`/`k` or number keys).
- `/settings`: Interactive configuration menu with single-key toggles for verbosity, thinking depth, and autonomy.
- `/doctor`: Run a diagnostic audit of local development toolchains (Zig, Git, cURL, Bun, Python, Rust, Clang).
- `/skills`: List and activate loaded domain playbooks.
- `/mcp`: List connected Model Context Protocol servers and registered tools.
- `/swarm`: Run a 4-subagent parallel inspection of the current project topology and security constraints.
- `/query <symbol>`: Search structural AST symbol declarations (`fn`, `struct`, `const`, `enum`) across the codebase.
- `/evolve`: Verify codebase module integrity and trigger automated release recompilation.
- `!<cmd>`: Execute any shell command directly through the pass-through runner.

---

## ⚙️ Configuration & Credentials

Configuration and authentication tokens are stored in `~/.ziggy/`:
- `~/.ziggy/config.json`: Runtime preferences (verbosity, autonomy limit, compaction thresholds).
- `~/.ziggy/credentials.json`: API keys for Groq, OpenRouter, Anthropic, Gemini, OpenAI, and Hugging Face.
- `~/.ziggy/context_ledger.jsonl`: Append-only continuity records for cross-session tracking.

---

## 📜 License

MIT License. Designed and built with Zig and Objective-C.
