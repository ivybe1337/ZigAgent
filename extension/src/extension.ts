import * as vscode from "vscode";
import * as path from "path";

const ZIGGY_PATH = "ziggy";

export function activate(context: vscode.ExtensionContext) {
  // Status Bar Item
  const statusBar = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusBar.text = "$(zap) ZigAgent (610KB)";
  statusBar.tooltip = "Click to launch ZigAgent Native REPL";
  statusBar.command = "zigagent.startREPL";
  statusBar.show();
  context.subscriptions.push(statusBar);

  // Command: Start REPL
  context.subscriptions.push(
    vscode.commands.registerCommand("zigagent.startREPL", () => {
      const term = vscode.window.createTerminal({
        name: "⚡ ZigAgent REPL",
        shellPath: ZIGGY_PATH,
      });
      term.show();
    })
  );

  // Command: Start TUI
  context.subscriptions.push(
    vscode.commands.registerCommand("zigagent.startTUI", async () => {
      const goal = await vscode.window.showInputBox({
        prompt: "Enter cognitive goal for ZigAgent TUI",
        value: "Inspect and optimize project topology",
      });
      if (!goal) return;

      const term = vscode.window.createTerminal({
        name: "⚡ ZigAgent TUI",
        shellPath: ZIGGY_PATH,
        shellArgs: ["tui", goal],
      });
      term.show();
    })
  );

  // Command: Run Doctor
  context.subscriptions.push(
    vscode.commands.registerCommand("zigagent.runDoctor", () => {
      const term = vscode.window.createTerminal({
        name: "⚡ ZigAgent Doctor",
        shellPath: ZIGGY_PATH,
        shellArgs: ["doctor"],
      });
      term.show();
    })
  );

  // Command: Show Memory
  context.subscriptions.push(
    vscode.commands.registerCommand("zigagent.showMemory", () => {
      const term = vscode.window.createTerminal({
        name: "⚡ ZigAgent Memory",
        shellPath: "/bin/bash",
        shellArgs: ["-c", `echo "/memory\n/exit" | ${ZIGGY_PATH}; read -n 1 -s -r -p "Press any key to close..."`],
      });
      term.show();
    })
  );

  // Command: Show Ledger
  context.subscriptions.push(
    vscode.commands.registerCommand("zigagent.showLedger", () => {
      const term = vscode.window.createTerminal({
        name: "⚡ ZigAgent Continuity Ledger",
        shellPath: "/bin/bash",
        shellArgs: ["-c", `echo "/ledger\n/exit" | ${ZIGGY_PATH}; read -n 1 -s -r -p "Press any key to close..."`],
      });
      term.show();
    })
  );
}

export function deactivate() {}
