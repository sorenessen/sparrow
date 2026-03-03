# 🕊 Sparrow

**Sparrow** is a desktop workspace runner built with **Tauri + Rust + TypeScript**.

It combines a real system shell (PTY-backed) with an opinionated task sidebar powered by `sparrow.toml`.
Think: terminal + lightweight task orchestrator + developer UX layer.

Sparrow is designed to make running project tasks feel intentional instead of ad-hoc.

---

## ✨ What Sparrow Is

Sparrow is:

- A real terminal (not simulated)
- A task runner driven by `sparrow.toml`
- A desktop app (macOS, Windows, Linux via Tauri)
- A bridge between structured workflows and raw shell power

Sparrow is **not**:

- A replacement for your shell
- A package manager
- A heavy build system

It’s a thin orchestration layer over your existing tools.

---

## 🧠 How It Works

Sparrow consists of two layers:

### 1) Rust Backend (Tauri)
- Spawns a real PTY (pseudo-terminal)
- Launches your system shell (e.g. `zsh`)
- Streams shell output to the UI
- Writes commands into the shell
- Reads `sparrow.toml` to discover tasks

### 2) TypeScript Frontend (Vite + xterm.js)
- Renders a real interactive terminal
- Displays a sidebar populated from `sparrow.toml`
- Allows clicking tasks to execute them
- Maintains full keyboard interactivity

When you click a task in the sidebar:
1. Sparrow reads the task commands from `sparrow.toml`
2. Writes those commands into the live shell
3. Output appears in the terminal as if typed manually

---

## 📁 Project Structure

```text
sparrow/
├── sparrow.toml          # Workspace configuration
├── sparrow-app/          # Tauri desktop app
│   ├── src/              # Frontend (TypeScript)
│   ├── src-tauri/        # Rust backend
│   ├── index.html
│   └── package.json
└── README.md
```

---

## ⚙️ sparrow.toml

Example:

```toml
[workspace]
name = "my-project"

[tasks]
up = ["npm install"]
build = ["npm run build"]
test = ["npm test"]
```

Each task is an array of shell commands.

Clicking a task executes those commands sequentially inside the live terminal.

---

## 🚀 Running Sparrow (Development)

### Prerequisites
- Node.js (v18+ recommended)
- Rust (stable toolchain)
- macOS, Windows, or Linux

Install Rust:
- https://rust-lang.org

### Install dependencies

```bash
cd sparrow-app
npm install
```

### Start development mode

```bash
npm run tauri dev
```

This will:
- Launch Vite (frontend dev server)
- Compile the Rust backend
- Open the Sparrow desktop window

---

## 🏗 Building a Production App

From inside `sparrow-app`:

```bash
npm run tauri build
```

The compiled desktop application will appear in:

```text
sparrow-app/src-tauri/target/release/bundle/
```

---

## 🖥 Using Sparrow

1. Launch the app
2. The sidebar loads workspace info from `sparrow.toml`
3. Click a task (e.g. `build`, `test`, `up`)
4. Watch it execute in the terminal
5. Continue using the shell normally

You can still type commands manually.

---

## 🎨 UI Features

- Dark themed terminal
- Sidebar task runner
- Click-to-run commands
- Clear terminal button
- Real shell process (not mocked)

---

## 🔐 Architecture Notes

- Uses `portable-pty` for PTY spawning
- Uses `tauri::Emitter` for streaming output
- Uses `OnceCell` to hold PTY writer state
- Parses TOML using `toml` crate
- Uses xterm.js + FitAddon for responsive terminal

---

## 🛣 Roadmap

Planned enhancements:

- Task status indicators (success/failure)
- Workspace auto-detection
- Recent runs history
- Markdown run logs viewer
- Multiple workspace support
- Integrated Sparrow CLI binary
- Terminal resizing sync
- Custom themes
- Configurable shell selection

---

## 🧩 Philosophy

Sparrow doesn’t try to abstract your tools.

It embraces the shell,
but gives structure to repetition.

Instead of remembering commands, you codify them.
Instead of switching contexts, you stay in one window.

---

## 📜 License

ISC

---

## 🕊 Sparrow

Terminal, but opinionated.
