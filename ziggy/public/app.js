const $ = (id) => document.getElementById(id);

async function api(path, opts = {}) {
  const res = await fetch(path, opts);
  return await res.json();
}

function eventNode(e) {
  const div = document.createElement("div");
  div.className = "event " + (e.level || "info");

  const top = document.createElement("div");
  top.className = "event-top";
  top.textContent = (e.level || "info") + " · " + (e.kind || "event");
  div.appendChild(top);

  const msg = document.createElement("p");
  msg.textContent = e.message || "";
  div.appendChild(msg);

  return div;
}

async function load() {
  const data = await api("/api/state");
  const s = data.state || {};

  $("phase").textContent = s.phase || "idle";
  $("step").textContent = String(s.step || 0);
  $("confidence").textContent = Number(s.confidence || 0).toFixed(2);
  $("running").textContent = String(s.running || false);
  $("summary").textContent = s.summary || "No summary yet.";
  $("final").textContent = s.final || "";
  $("config").textContent = JSON.stringify(data.config || {}, null, 2);

  const pending = $("pending");
  pending.innerHTML = "";
  if (!data.pending || !data.pending.length) {
    pending.textContent = "No pending approvals.";
  }

  const events = $("events");
  events.innerHTML = "";
  for (const e of (data.events || []).slice().reverse()) {
    events.appendChild(eventNode(e));
  }
}

$("run").onclick = async () => {
  await api("/api/run", {
    method: "POST",
    body: $("goal").value
  });
  await load();
};

$("refresh").onclick = load;

setInterval(load, 1500);
load();
