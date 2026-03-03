import { Terminal } from "xterm";
import "xterm/css/xterm.css";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { FitAddon } from "xterm-addon-fit";

type WorkspaceStatus = {
  name: string;
  tasks: string[];
  toml_path: string;
};

const el = document.getElementById("terminal");
if (!el) throw new Error("Missing #terminal");

const term = new Terminal({
  cursorBlink: true,
  convertEol: true,
  fontSize: 15,
  lineHeight: 1.2,
  fontFamily: 'MesloLGS NF, "JetBrainsMono Nerd Font", Menlo, Monaco, "SF Mono", monospace',
  fontSize: 15,
  theme: {
    background: "#0b0d10",
    foreground: "#d7dde8",
    cursor: "#d7dde8",
    selectionBackground: "#2a3140",
  },
});

const fit = new FitAddon();
term.loadAddon(fit);

term.open(el);
fit.fit();
window.addEventListener("resize", () => fit.fit());
term.focus();

listen<string>("pty_output", (event) => {
  term.write(event.payload);
});

term.onData((data) => {
  invoke("pty_write", { data });
});

async function loadSidebar() {
  const ws = await invoke<WorkspaceStatus>("get_workspace_status");
  const nameEl = document.getElementById("workspaceName");
  if (nameEl) nameEl.textContent = ws.name;

  const tasksEl = document.getElementById("tasks");
  if (!tasksEl) return;

  tasksEl.innerHTML = "";
  ws.tasks.sort().forEach((t) => {
    const row = document.createElement("div");
    row.className = "task";
    row.innerHTML = `
      <div>
        <div class="name">${t}</div>
        <div class="hint">run</div>
      </div>
      <div class="hint">↵</div>
    `;
    row.addEventListener("click", async () => {
      await invoke("run_task", { task: t });
      term.focus();
    });
    tasksEl.appendChild(row);
  });

  const clearBtn = document.getElementById("btnClear");
  clearBtn?.addEventListener("click", () => {
    term.clear();
    term.focus();
  });
}

invoke("spawn_shell");
loadSidebar();