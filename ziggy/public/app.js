// ZigAgent Mobile Companion Engine
document.addEventListener("DOMContentLoaded", () => {
  const urlParams = new URLSearchParams(window.location.search);
  const authToken = urlParams.get("token") || localStorage.getItem("ziggy_token") || "";
  if (authToken) localStorage.setItem("ziggy_token", authToken);

  // Tab switching
  const tabBtns = document.querySelectorAll(".tab-btn");
  const tabContents = document.querySelectorAll(".tab-content");

  tabBtns.forEach(btn => {
    btn.addEventListener("click", () => {
      tabBtns.forEach(b => b.classList.remove("active"));
      tabContents.forEach(c => c.classList.remove("active"));
      btn.classList.add("active");
      const target = document.getElementById(`tab-${btn.dataset.tab}`);
      if (target) target.classList.add("active");
      if (btn.dataset.tab === "diff") loadDiff();
    });
  });

  // Quick Chips
  document.querySelectorAll(".chip").forEach(chip => {
    chip.addEventListener("click", () => {
      const input = document.getElementById("user-input");
      input.value = chip.dataset.cmd;
      document.getElementById("chat-form").dispatchEvent(new Event("submit"));
    });
  });

  // Emergency Halt
  document.getElementById("btn-esc-halt").addEventListener("click", () => {
    appendMessage("system", "⚡ [EMERGENCY HALT] <ESC> Interrupt signal dispatched to Ziggy runtime.");
    fetch("/api/interrupt", { method: "POST" }).catch(() => {});
  });

  // Voice Input (Web Speech API)
  const btnVoice = document.getElementById("btn-voice");
  if ("webkitSpeechRecognition" in window || "SpeechRecognition" in window) {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    const recognition = new SpeechRecognition();
    recognition.continuous = false;
    recognition.interimResults = false;

    recognition.onresult = (e) => {
      const text = e.results[0][0].transcript;
      document.getElementById("user-input").value = text;
      btnVoice.style.color = "";
    };

    recognition.onerror = () => { btnVoice.style.color = ""; };
    recognition.onend = () => { btnVoice.style.color = ""; };

    btnVoice.addEventListener("click", () => {
      btnVoice.style.color = "var(--accent-red)";
      recognition.start();
    });
  } else {
    btnVoice.style.display = "none";
  }

  // Chat Form Submit
  const chatForm = document.getElementById("chat-form");
  const userInput = document.getElementById("user-input");
  const chatStream = document.getElementById("chat-stream");

  chatForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const text = userInput.value.trim();
    if (!text) return;

    userInput.value = "";
    appendMessage("user", text);

    // Simulate / execute directive
    appendMessage("agent", "⚡ Ziggy received directive. Processing action plan natively...");
    
    try {
      const res = await fetch("/api/status");
      if (res.ok) {
        const data = await res.json();
        updateHUD(data);
      }
    } catch (_) {}
  });

  function appendMessage(role, content) {
    const div = document.createElement("div");
    div.className = `msg ${role}`;
    div.innerHTML = `<div class="msg-body">${escapeHtml(content)}</div>`;
    chatStream.appendChild(div);
    chatStream.scrollTop = chatStream.scrollHeight;
  }

  function updateHUD(data) {
    if (data.workspace) document.getElementById("hud-workspace").textContent = data.workspace;
    if (data.model) document.getElementById("hud-model").textContent = data.model;
    if (data.fill_pct !== undefined) {
      document.getElementById("hud-progress-bar").style.width = `${data.fill_pct}%`;
      document.getElementById("hud-tokens").textContent = `${data.tokens || 2400} / ${data.max_tokens || 128000} tokens (${data.fill_pct}%)`;
    }
  }

  async function loadDiff() {
    const box = document.getElementById("diff-content");
    box.textContent = "Loading git diff...";
    try {
      const res = await fetch("/api/diff");
      const text = await res.text();
      box.textContent = text || "No active git diff.";
    } catch (err) {
      box.textContent = "Failed to load git diff from remote host.";
    }
  }

  document.getElementById("btn-refresh-diff")?.addEventListener("click", loadDiff);

  function escapeHtml(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }
});
