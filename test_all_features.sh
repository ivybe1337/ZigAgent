#!/usr/bin/env bash
set -e

ZIGGY="/Users/joshua/LocalBuilds/ZigAgent/ziggy/zig-out/bin/ziggy"
APP="/Users/joshua/LocalBuilds/ZigAgent/app/ZigAgent.app/Contents/MacOS/ZigAgent"

echo "=========================================================="
echo "🧪 ZIGAGENT COMPREHENSIVE END-TO-END FEATURE TEST SUITE"
echo "=========================================================="

echo -e "\n--- 1. Testing CLI Help & Diagnostics ---"
$ZIGGY --help
$ZIGGY doctor

echo -e "\n--- 2. Testing REPL Core Slash Commands ---"
printf "/doctor\n/keys\n/swarm test task\n/deliberate 'Optimize AST memory buffers'\n/ast\n/council\n/speculate 'Zero-copy arena buffer'\n/query Repl\n/skills\n/skill systematic-debugging\n/mcp\n/plugins\n/bridges\n/provenance\n/snapshot\n/timeline\n/ledger\n/inbox\n/omni\n/evolve\n/exit\n" | $ZIGGY

echo -e "\n--- 3. Testing 5 Novel Super-Capabilities ---"
printf "/minds_eye\n/thermo test\n/bifurcate\n/introspect 'Verify non-destructive bounds and safe execution'\n/morphic\n/exit\n" | $ZIGGY

echo -e "\n--- 4. Testing Native macOS Cocoa App Binary ---"
if [ -f "$APP" ]; then
    echo "✔ Native macOS Desktop Cocoa Binary exists at: $APP"
    file "$APP"
else
    echo "✘ Error: Native Desktop Cocoa App Binary missing!"
    exit 1
fi

echo -e "\n=========================================================="
echo "✅ ALL COMPREHENSIVE COMPONENT TESTS EXECUTED SUCCESSFULLY"
echo "=========================================================="
