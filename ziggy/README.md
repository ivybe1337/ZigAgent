# ZigAgent Core (Ziggy)

The pure native Zig implementation of the ZigAgent CLI, autonomous ReAct engine, and tool runtime.

## Directory Layout
- `src/main.zig`: Entry point for CLI flags and REPL startup.
- `src/repl.zig`: Interactive REPL interface matching standard AgY dual-divider prompt styling.
- `src/http.zig`: High-throughput HTTP client with direct Groq LPU, OpenRouter, and Ollama routing.
- `src/models.zig`: Interactive scrollable terminal model browser with Darwin termios support.
- `src/tools.zig`: Native file, directory, grep, find, web, and git operations.
- `src/memory.zig`: L1 ring buffer and L3 SHA-256 Merkle root verification.
- `src/mcp.zig`: JSON-RPC 2.0 Model Context Protocol host and tool dispatcher.
- `src/skills.zig`: Dynamic domain playbook and `SKILL.md` parser.
- `src/security.zig`: Path traversal and destructive command verification.
- `src/sys.zig`: Low-level POSIX system call bindings with macOS Darwin support.

## Building
```bash
zig build -Doptimize=ReleaseFast
```
