import { Terminal } from "xterm";
import "xterm/css/xterm.css";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

const el = document.getElementById("terminal");
if (!el) throw new Error("Missing #terminal");

const term = new Terminal({
  cursorBlink: true,
  convertEol: true,
  fontSize: 13,
});

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