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
  scrollback: 5000,
  fontFamily:
    '"JetBrainsMono Nerd Font", "MesloLGS NF", "SF Mono", Menlo, Monaco, Consolas, monospace',
  fontSize: 15,
  lineHeight: 1.2,
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
term.focus();

// --- PTY output -> terminal ---
listen<string>("pty_output", (event) => {
  term.write(event.payload);
});

// --- terminal input -> PTY ---
term.onData((data) => {
  // xterm sends "\r" for Enter, which is correct for a PTY.
  invoke("pty_write", { data }).catch(console.error);
});

// --- size sync (this fixes the "missing chars" / weird prompt wrapping / quote oddities) ---
let resizeTimer: number | null = null;

async function syncPtySize() {
  // Fit first so term.cols/rows are correct.
  fit.fit();

  const cols = term.cols;
  const rows = term.rows;

  // Backend resize (preferred, doesn’t pollute shell history)
  try {
    await invoke("pty_resize", { cols, rows });
    return;
  } catch {
    // Back-compat fallback if pty_resize isn't wired yet.
    // This is less ideal (it runs a command in the shell), but it fixes the behavior.
    await invoke("pty_write", { data: `stty cols ${cols} rows ${rows}\n` });
  }
}

function requestResizeSync() {
  if (resizeTimer) window.clearTimeout(resizeTimer);
  resizeTimer = window.setTimeout(() => {
    void syncPtySize();
  }, 75);
}

// Keep PTY sized to the actual pixel container.
window.addEventListener("resize", requestResizeSync);
new ResizeObserver(requestResizeSync).observe(el);

// Fonts can load async; do an extra fit after they're ready.
// This prevents the initial cols/rows from being wrong.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const fonts: any = (document as any).fonts;
if (fonts?.ready) {
  fonts.ready.then(() => requestResizeSync()).catch(() => {});
}

async function loadSidebar() {
  const ws = await invoke<WorkspaceStatus>("get_workspace_status");
  const pathInput = document.getElementById("workspacePath") as HTMLInputElement | null;
  if (pathInput && ws.toml_path) {
    // show the directory containing sparrow.toml if you want:
    // pathInput.value = ws.toml_path.replace(/\/sparrow\.toml$/, "");
    // but simplest: leave user-entered value as-is; status shows toml path
  }

const statusEl = document.getElementById("workspaceStatus");
if (statusEl) statusEl.textContent = ws.toml_path;
  const nameEl = document.getElementById("workspaceName");
  if (nameEl) nameEl.textContent = ws.name;

  const tasksEl = document.getElementById("tasks");
  if (!tasksEl) return;

  tasksEl.innerHTML = "";
  ws.tasks
    .slice()
    .sort()
    .forEach((t) => {
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

  // Sidebar affects layout width; re-fit after it's populated.
  requestResizeSync();
}

// Start shell, then immediately sync sizing.
invoke("spawn_shell")
  .then(() => requestResizeSync())
  .catch(console.error);

void loadSidebar();

async function setWorkspace(path: string) {
  const trimmed = path.trim();
  if (!trimmed) return;

  const statusEl = document.getElementById("workspaceStatus");
  if (statusEl) statusEl.textContent = "Loading…";

  try {
    const ws = await invoke<WorkspaceStatus>("set_workspace", { path: trimmed });

    // Refresh UI based on backend truth
    const nameEl = document.getElementById("workspaceName");
    if (nameEl) nameEl.textContent = ws.name;

    if (statusEl) statusEl.textContent = ws.toml_path;

    await loadSidebar();
    term.focus();
  } catch (e) {
    if (statusEl) statusEl.textContent = String(e);
    console.error(e);
  }
}

function wireWorkspaceInput() {
  const input = document.getElementById("workspacePath") as HTMLInputElement | null;
  if (!input) return;

  input.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter") {
      void setWorkspace(input.value);
    }
  });

  // optional: on blur (click away), also apply
  input.addEventListener("blur", () => {
    void setWorkspace(input.value);
  });
}

function wireWorkspaceControls() {
  const pathEl = document.getElementById("workspacePath") as HTMLInputElement | null;
  const browseBtn = document.getElementById("btnBrowseWorkspace");

  pathEl?.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter") void setWorkspace(pathEl.value);
  });

  browseBtn?.addEventListener("click", async () => {
    // We'll add a backend command that opens a folder dialog and returns the chosen path
    try {
      const chosen = await invoke<string>("pick_workspace_folder");
      if (chosen) await setWorkspace(chosen);
    } catch (e) {
      console.error(e);
    }
  });
}

wireWorkspaceControls();
wireWorkspaceInput();
