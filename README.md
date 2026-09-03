# ⚡ ZigAgent (Ziggy)

> **Native Autonomous AI Coding Agent, REPL & Spatial Runtime in Zig 0.16.0 & macOS Cocoa**

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

## 📌 Executive Overview

**ZigAgent** (**Ziggy**) is an autonomous AI coding assistant and agentic execution environment built natively with **Zig 0.16.0** and **Objective-C / Cocoa**. It eliminates the runtime bloat, multi-gigabyte memory footprints, and non-deterministic GC latency of Python and Node.js agent frameworks.

Compiled directly to a standalone Mach-O release binary (~750 KB), ZigAgent delivers:
- **Instantaneous Sub-Millisecond Startup**: Ready to execute in under 3 ms.
- **Deterministic Step-Arena Memory**: Zero garbage collection pauses, step-bounded arena recycling, and guaranteed memory release on turn completion.
- **High-Throughput Neural Routing**: Direct Groq LPU streaming (300+ tokens/sec) for frontier models (`openai/gpt-oss-120b`, `qwen/qwen3.8-27b`), with universal OpenRouter and local Ollama failover.
- **Model Context Protocol (MCP)**: Native JSON-RPC 2.0 client for discovering and executing external tools.
- **Native macOS Desktop Studio**: Three-column studio featuring live chat, embedded WebKit browser, editable code preview with markdown/HTML rendering, and an integrated shell terminal.

---

## 🌟 5 Novel Architectural Super-Capabilities

ZigAgent incorporates 5 groundbreaking native capabilities designed to expand what an autonomous agent can execute locally:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       5 NOVEL ZIGAGENT SUPER-CAPABILITIES                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. Mind's Eye Spatial Vision & Computer-Use:                               │
│     Native macOS display capture (screencapture / CoreGraphics), window     │
│     enumeration, and OS-level coordinate grounding (mouse_click, type).     │
│                                                                             │
│  2. Thermodynamic Associative Holographic Memory:                           │
│     Energy-decay graph network with activation pumping and half-life        │
│     cooling. Pulls resonant context into working memory before generation.  │
│                                                                             │
│  3. Bifurcated Dual-Hemisphere Speculative Inference:                       │
│     Right hemisphere concurrently pre-validates file paths, delimiters,     │
│     and security bounds while left hemisphere generates tokens. Zero stalls.│
│                                                                             │
│  4. Metacognitive Epistemic Invariant Self-Proof:                           │
│     Deconstructs thoughts into formal atomic claims (existence, syntax,     │
│     safety) and enforces self-healing intercepts prior to system calls.     │
│                                                                             │
│  5. Morphogenetic Machine-Code Tool Weaver:                                 │
│     Autonomously synthesizes standalone Zig micro-tools, compiles them to   │
│     Mach-O release binaries via `zig build-exe`, and registers them live.  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1. "Mind's Eye" Spatial Vision & Computer Use (`src/minds_eye.zig`)
Enables direct visual and spatial perception without Python Playwright or heavy container runtimes.
- Zero-latency display snapshots via native macOS display APIs.
- Window bounds enumeration and coordinate mapping.
- Native OS-level event dispatch: `mouse_click(x, y)`, `mouse_move(x, y)`, `keyboard_type(text)`, and `window_focus(app_name)`.

### 2. Thermodynamic Holographic Associative Memory (`src/thermodynamic_memory.zig`)
Memory nodes operate as an energy-activation graph rather than static flat vectors:
- **Activation Energy ($E \in [0, 100]$)**: Referenced memories gain thermal energy ($\Delta E = +35.0$).
- **Half-Life Cooling**: Memories cool exponentially over time ($E(t) = E_0 \cdot e^{-\lambda \Delta t}$).
- **Constructive Resonance**: Co-occurring concepts build associative graph edges, pulling relevant historical context into the L1 working memory cache.

### 3. Bifurcated Dual-Hemisphere Speculative Inference (`src/bifurcation.zig`)
Runs an analytical speculation pipeline concurrently with token streaming:
- Evaluates candidate tool invocations before the generative model finishes outputting.
- Pre-checks file existence, AST delimiter balance, and security bounds.
- Eliminates sequential round-trip wait states and intercepts divergence early.

### 4. Metacognitive Epistemic Invariant Self-Proof (`src/introspective_engine.zig`)
Enforces internal reasoning consistency through formal invariant gates:
- Intercepts planned actions before OS execution.
- Verifies resource claims (target file/directory accessibility).
- Verifies structural syntax claims via balanced delimiter checking (`ASTGuard`).
- If an invariant fails, automatically steers the model's reasoning loop to correct the plan before any side effects occur.

### 5. Morphogenetic Machine-Code Tool Weaver (`src/morphogenetic.zig`)
Enables the agent to autonomously generate, compile, and link new native binaries:
- Synthesizes pure Zig source code tailored to a specialized task.
- Compiles directly to a native Mach-O binary in `~/.ziggy/morphogenetic_tools/` via `zig build-exe -OReleaseFast`.
- Dynamically registers the binary into Ziggy's active tool dispatcher.

---

## 🏗️ Core Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ZIGAGENT ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  [User Frontends]                                                           │
│  • Interactive Terminal REPL:          ziggy                                │
│  • Native macOS Cocoa Studio:          ZigAgent.app                         │
│  • Local HTTP / WebSocket Canvas:      Port 4040 Web Server                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  [Execution & Reasoning Pipeline]                                           │
│  • Autonomous ReAct Action Loop:       Tool execution -> Result feedback    │
│  • Multi-Pass Deliberation Engine:     Hypothesis -> Critique -> Synthesis  │
│  • AST Syntax & Delimiter Guard:       Structural balanced delimiter checks │
│  • 3-Lens Consensus Council:           Security / Performance / Architecture│
├─────────────────────────────────────────────────────────────────────────────┤
│  [Protocols & Extensions]                                                   │
│  • Model Context Protocol (MCP):       JSON-RPC 2.0 stdio client            │
│  • Specialized Skill System:           Dynamic SKILL.md playbook loader     │
│  • Omnichannel Messaging Gateways:     Telegram Bot, iMessage (osascript)   │
├─────────────────────────────────────────────────────────────────────────────┤
│  [State & Continuity]                                                       │
│  • L1 Memory Ring Buffer:              Hot in-memory context tracking       │
│  • L3 Merkle Root DAG:                 SHA-256 state verification           │
│  • Context Ledger:                     Append-only JSONL continuity records │
│  • Time Machine Snapshots:             Point-in-time workspace rollbacks    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Building & Running

### Prerequisites
- **Zig 0.16.0**
- **Apple Clang** (for `ZigAgent.app`)
- **cURL** and **Git**

### 1. Build & Install the CLI
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

## 💻 CLI Commands & Interaction

Launch the interactive REPL:
```bash
ziggy
```

### Key Slash Commands
- `/minds_eye`: Capture active screen and report display geometry for visual grounding.
- `/thermo [query]`: Inspect active thermodynamic working memory and concept activations.
- `/bifurcate`: View dual-hemisphere speculative execution telemetry.
- `/introspect <statement>`: Run epistemic invariant self-proof on a plan or code statement.
- `/morphic`: List dynamically synthesized native Zig micro-tools.
- `/models`: Interactive OpenRouter-style scrollable model browser (`↑`/`↓` arrow keys).
- `/settings`: Interactive configuration panel with single-key toggles.
- `/doctor`: Diagnostic audit of local toolchains (Zig, Git, cURL, Bun, Python, Rust, Clang).
- `/swarm`: Run a 4-subagent parallel project topology and security audit.
- `/skills`: Discover and activate local domain playbooks from `~/.agent/skills/`.
- `/mcp`: List connected Model Context Protocol servers and tools.
- `!<cmd>`: Execute any shell command via pass-through runner.

---

## ⚙️ Configuration & Storage

Files are maintained in `~/.ziggy/`:
- `~/.ziggy/credentials.json`: API credentials (Groq, OpenRouter, etc.).
- `~/.ziggy/config.json`: Execution parameters and thinking effort presets.
- `~/.ziggy/vision/`: High-resolution display captures from Mind's Eye.
- `~/.ziggy/memory/`: Thermodynamic associative energy graph.
- `~/.ziggy/morphogenetic_tools/`: Dynamically compiled standalone micro-tools.
- `~/.ziggy/context_ledger.jsonl`: Cross-session continuity stream.

---

## 📜 License

MIT License. Engineered in Zig and Objective-C.
