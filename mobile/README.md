# 📱 ZigAgent Mobile Companion

> **Cross-Platform iOS, Android & PWA Remote Control Center for ZigAgent (Ziggy)**

The ZigAgent Mobile Companion connects directly to your desktop or remote server running `ziggy serve`, providing full control over your autonomous coding agent on the go.

---

## ✨ Features

- **🔴 Emergency Halt (<ESC>)**: Tap the halt button to instantly pause or terminate running toolchains mid-flight.
- **💬 Live Action & Thinking Stream**: Inspect the agent's real-time `<think>` transcripts, tool calls, and terminal logs.
- **🎙️ Voice Directives**: Dictate tasks and steering instructions hands-free via speech-to-text.
- **📊 Real-Time Context HUD**: Monitor token consumption, active models, reasoning depth, and context fill percentages.
- **🗂️ Mobile Git Diff & File Browser**: Review code changes and diffs directly from your phone.
- **🔐 Zero-Config Pairing**: Pair instantly over local Wi-Fi, Tailscale, or public tunnels using one-time tokens.

---

## 🚀 Quickstart

### Option 1: Instant PWA (No install required)
1. On your computer, run:
   ```bash
   ziggy serve
   ```
2. Open the printed local or LAN URL on your phone's browser (Safari or Chrome):
   ```
   http://<YOUR-IP>:4040?token=<YOUR-TOKEN>
   ```
3. Tap **Share** ➔ **Add to Home Screen** for a full native fullscreen experience.

---

### Option 2: Native React Native / Expo App
```bash
# 1. Install dependencies
cd mobile
bun install

# 2. Start Expo dev server
bun run start

# 3. Open on iOS / Android via Expo Go or simulator
bun run ios
bun run android
```
