import { Terminal } from "xterm";
import "xterm/css/xterm.css";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { FitAddon } from "xterm-addon-fit";

const el = document.getElementById("terminal");
if (!el) throw new Error("Missing #terminal");

const term = new Terminal({
  cursorBlink: true,
  convertEol: true,
  fontSize: 15,           // bigger
  lineHeight: 1.2,
  fontFamily: 'Menlo, Monaco, "SF Mono", Consolas, "Liberation Mono", monospace',
  theme: {
    background: "#0b0d10",
    foreground: "#d7dde8",
    cursor: "#d7dde8",
    selectionBackground: "#2a3140",
  },
});

const fit = new FitAddon();
term.loadAddon(fit);
fit.fit();

window.addEventListener("resize", () => fit.fit());

term.open(el);
term.focus();

// Listen for output from Rust
listen<string>("pty_output", (event) => {
  term.write(event.payload);
});

// Send keystrokes to Rust
term.onData((data) => {
  invoke("pty_write", { data });
});

// Spawn shell on startup
invoke("spawn_shell");

const splash = document.getElementById("splash");
setTimeout(() => splash?.classList.add("hidden"), 650);
