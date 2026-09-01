# ⚡ ZigAgent (Ziggy)

> **Ultra-Fast, 100% Pure Native Autonomous AI Agent, Hybrid Reasoning Engine & MCP Host in Zig 0.16.0 & Cocoa**

<p align="center">
  <img src="app/AppIcon.iconset/icon_512x512.png" width="140" alt="ZigAgent Icon" style="border-radius: 28px;" />
</p>

<p align="center">
  <a href="#-key-benchmarks"><img src="https://img.shields.io/badge/Binary_Footprint-610_KB-00f2fe?style=for-the-badge" alt="Binary Size" /></a>
  <a href="#-key-benchmarks"><img src="https://img.shields.io/badge/Startup_Time-%3C_2ms-00e676?style=for-the-badge" alt="Startup" /></a>
  <a href="#-key-benchmarks"><img src="https://img.shields.io/badge/GC_Pauses-Zero_(Arena_Recycled)-ff6b35?style=for-the-badge" alt="Zero GC" /></a>
  <a href="#-model-context-protocol-mcp-skills--plugins"><img src="https://img.shields.io/badge/MCP-JSON--RPC_2.0-7928ca?style=for-the-badge" alt="MCP" /></a>
</p>

---

## 🌟 Executive Overview

**ZigAgent** (**Ziggy**) is a next-generation autonomous AI engineering runtime written from scratch in pure native **Zig 0.16.0** and **Objective-C / Cocoa**. Designed to eliminate the bloat, multi-gigabyte memory footprints, and heavy runtime overhead of Node.js/Python agent frameworks, ZigAgent delivers instantaneous sub-millisecond execution, thermodynamic memory engrams, and native Model Context Protocol (MCP) server integration.

Whether running in headless CI, an interactive true-color terminal TUI, or the native macOS desktop app, ZigAgent provides full-turn autonomous problem solving with continuous verification.

---

## 🚀 Key Benchmarks

| Metric | ZigAgent (Ziggy) | Traditional Node/Python Agents | Advantage |
| :--- | :--- | :--- | :--- |
| **Binary Size** | **610 KB** (ReleaseFast) | ~450 MB – 1.2 GB (Runtime + node_modules) | **99.9% smaller** |
| **Startup Latency** | **< 2 ms** | 1,800 ms – 4,500 ms | **900x faster** |
| **Idle Memory (RAM)**| **< 5 MB** | 250 MB – 800 MB | **98% less memory** |
| **Memory Allocation**| **Zero-GC Arena Recycling** | Unpredictable GC pauses & leaks | **Deterministic lifecycle** |
| **Engram Throughput**| **21,500+ ops/sec** | ~800 ops/sec | **26x throughput** |

---

## 🧠 10 Foundational Architectural Systems

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ZIGAGENT ARCHITECTURAL OVERVIEW                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  [1. Frontends & Control Centers]                                           │
│  • Interactive Terminal REPL:          ziggy                                │
│  • Live Telemetry HUD TUI:             ziggy tui "<goal>"                   │
│  • Manus-Style Cloud Desktop:          Port 4040 Web Canvas (3-column UI)   │
│  • Native macOS Cocoa Desktop App:     ZigAgent.app                         │
│  • Mobile Companion App (iOS/Android): mobile/ & PWA                        │
│  • VS Code Native Extension:           extension/                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  [2. Cognitive Planning & Execution]                                        │
│  • 4-Pass Recursive Metacognition:     Think -> Challenge -> Rethink -> Ref │
│  • Autonomous Self-Improvement:        Self-recompile with hot-restart wake │
│  • Unbounded Action Loop:              Infinite step invariant convergence  │
│  • Non-Blocking ESC Interruption:      Mid-flight pause & steering inject   │
│  • 3-Lens Consensus Council:           Security / Perf / Arch cross-critique│
│  • AST Syntax Integrity Guard:         Balanced delimiter synthesis filter  │
├─────────────────────────────────────────────────────────────────────────────┤
│  [3. Dynamic Protocols, Omnichannel & Extensions]                           │
│  • Omnichannel Messaging Bridges:      iMessage, Telegram, WhatsApp, RCS    │
│  • MCP Server Host (JSON-RPC 2.0):     Dynamic stdio tool discovery & call  │
│  • Domain Playbook Skill System:       Modular markdown/YAML workflows      │
│  • Dynamic Plugin Registry:            Binary & script capability hooks     │
│  • Pass-Through Shell Engine:          Instant `!<cmd>` execution           │
├─────────────────────────────────────────────────────────────────────────────┤
│  [4. Epistemic Memory & Global Continuity]                                  │
│  • Thermodynamic Memory Ring:          Exponential decay scoring (L1 Ring)  │
│  • Content-Addressed Merkle Forest:    SHA-256 state DAG verification (L3) │
│  • Pre-Compaction State Dumps:         Automatic token budget preservation  │
│  • Cross-Agent Continuity Ledger:      Session handoffs across projects     │
│  • OmniLattice Mesh Bridge:            Decentralized memory distribution    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔌 Model Context Protocol (MCP), Skills & Plugins

### 1. Model Context Protocol (MCP)
ZigAgent natively acts as an **MCP Client** over standard JSON-RPC 2.0. It discovers and invokes tools hosted on external servers (e.g., OmniLattice, filesystem servers, database connectors).
```bash
# List active MCP servers and available tools
ziggy ❯ /mcp

# Connect custom servers in ~/.ziggy/mcp.json
```

### 2. Specialized Domain Skills
Load domain-specific playbooks and operational procedures dynamically:
- `systematic-debugging`: Invariant tracing and root-cause analysis
- `tdd-workflow`: Red-Green-Refactor test cycle with zero regressions
- `ast-architecture`: Structural syntax verification
- `omnilattice-sync`: State synchronization over Merkle DAGs
- `performance-optimization`: Zero-allocation inline buffers and arena tuning
- `api-security-audit`: OWASP testing and input sanitization

```bash
ziggy ❯ /skills
ziggy ❯ /skill tdd-workflow
```

### 3. Dynamic Plugin & Extension Host
Extend ZigAgent's core capabilities using standalone binaries, Python/Shell scripts, or IDE extensions placed in `~/.ziggy/plugins/`.

---

## ⌨️ Command Reference

| Category | Command | Description |
| :--- | :--- | :--- |
| **Shell** | `!<cmd>` | Run direct terminal commands instantly (`!ls -la`, `!git status`, `!zig build`) |
| **Settings** | `/settings` | Open interactive full-screen TUI settings panel (9 controls) |
| **Deliberation**| `/deliberate <goal>` | Run 4-pass recursive metacognition (Think -> Challenge -> Rethink -> Refine) |
| **Swarm** | `/swarm <task>` | Launch 4-agent parallel swarm orchestration (Researcher, Coder, Auditor, QA) |
| **AST Search** | `/query <symbol>` | Fast structural AST symbol query across codebase |
| **Self-Evolution**| `/evolve` | Run autonomous codebase self-analysis and hot-recompile |
| **Messaging** | `/listen` | Start live inbound messaging listener daemon (Telegram/iMessage/WhatsApp) |
| **Messaging** | `/bridges` | Inspect iMessage, Telegram, WhatsApp, and Google Messages gateways |
| **Messaging** | `/msg <plat> <to> <txt>` | Dispatch outbound message via bridge |
| **Protocols**| `/mcp` | List connected MCP servers and external tools |
| **Skills** | `/skills` | Browse loaded skill playbooks (`/skill <name>` to activate) |
| **Plugins** | `/plugins` | Inspect installed plugins and extension bridges |
| **Continuity**| `/omni` | Synchronize Merkle DAG with OmniLattice Forest |
| **Continuity**| `/ledger` | View cross-agent session continuity stream & handoffs |
| **Continuity**| `/inbox` | Check inter-agent peer message queues |
| **Reasoning**| `/speculate` | Multi-branch candidate evaluation engine |
| **Reasoning**| `/council` | Run 3-lens multi-perspective consensus evaluation |
| **Integrity**| `/ast` | Verify balanced delimiter AST integrity |
| **State** | `/snapshot` | Create point-in-time state checkpoint in Time Machine |
| **System** | `/doctor` | Run comprehensive system toolchains audit |

---

## 🛠️ Installation & Building

### Prerequisites
- **Zig 0.16.0+**
- **Git**, **cURL**

### 1. Build Native CLI (`ziggy`)
```bash
cd ziggy
zig build -Doptimize=ReleaseFast

# Test the binary
./zig-out/bin/ziggy

# Optional: Add to PATH
mkdir -p ~/.local/bin
ln -sf $(pwd)/zig-out/bin/ziggy ~/.local/bin/ziggy
```

### 2. Cross-Compile for Windows & Linux
```bash
# Build standalone Windows x86_64 executable
zig build windows -Doptimize=ReleaseFast

# Build for Linux x86_64
zig build -Dtarget=x86_64-linux -Doptimize=ReleaseFast
```

### 3. Build Native macOS Desktop App (`ZigAgent.app`)
```bash
cd app
clang -framework Cocoa -O3 src/main.m -o ZigAgent.app/Contents/MacOS/ZigAgent
open ZigAgent.app
```

---

## 📱 Remote Cloud Gateway & Mobile Companion

Launch the embedded HTTP & WebSocket gateway to access ZigAgent while away:
```bash
ziggy serve 4040
# Or from inside the REPL:
ziggy ❯ /remote
```

- **Instant Mobile Access**: Open `http://<YOUR-IP>:4040?token=<TOKEN>` on iOS Safari / Android Chrome and tap **Add to Home Screen** for a full native PWA experience.
- **Native Mobile App**: Open `mobile/` and run `bun start` to launch the React Native / Expo companion app with emergency `<ESC>` halts, live voice dictation, and git diff review.

---

## 🛡️ Epistemic Invariants & Security Model

ZigAgent operates under strict mathematical invariants to ensure safety and code correctness:
1. **Non-Destructive Execution Guard**: Destructive root commands (`rm -rf /`, raw disk formatting) are automatically intercepted and rejected.
2. **Path Traversal Sanitization**: Prevents unauthorized file reads/writes outside project roots.
3. **Secret Redaction**: API keys (`gsk_`, `sk-or-v1-`) are masked across logs, engrams, and transcripts.
4. **Context Compaction Gate**: Automatically triggers pre-compaction engram snapshots to the Merkle Forest when context fill reaches user-configured thresholds (default 75%).

---

## 📜 License

MIT License © 2026 ivybe1337
