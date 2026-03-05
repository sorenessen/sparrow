
# 🕊 Sparrow

**Sparrow** is a desktop workspace runner built with **Tauri + Rust + TypeScript**.

It combines a real system shell (PTY-backed) with an opinionated task sidebar powered by `sparrow.toml`.

Think: **terminal + task orchestrator + developer UX layer.**

Sparrow is designed to make running project tasks intentional instead of ad‑hoc.

---

# ✨ What Sparrow Is

Sparrow is:

- A real terminal (PTY shell, not simulated)
- A task runner driven by `sparrow.toml`
- A desktop app (macOS, Windows, Linux via Tauri)
- A bridge between structured workflows and raw shell power

Sparrow is **not**:

- A replacement for your shell
- A package manager
- A heavy build system

It is intentionally thin and lets your existing tools do the work.

---

# 🧠 Architecture

Sparrow has two main layers.

## Rust Backend (Tauri)

Responsibilities:

- Spawn a real PTY shell (`zsh`, `bash`, etc)
- Stream shell output to the UI
- Accept keyboard input from the terminal
- Parse `sparrow.toml`
- Discover available tasks
- Execute tasks by writing commands into the shell

Key crates:

- `portable-pty`
- `tauri`
- `serde`
- `toml`

## TypeScript Frontend

Built with:

- Vite
- xterm.js
- FitAddon

Responsibilities:

- Render the terminal
- Resize the terminal correctly
- Display the sidebar task list
- Send commands to the backend
- Stream shell output to the UI

---

# 📁 Project Structure

```
sparrow/
├── sparrow.toml          # workspace configuration
├── sparrow-app/
│   ├── src/              # frontend
│   │   ├── main.ts
│   │   └── styles.css
│   │
│   ├── src-tauri/        # rust backend
│   │   └── main.rs
│   │
│   ├── index.html
│   └── package.json
└── README.md
```

---

# ⚙️ sparrow.toml

Sparrow uses a `sparrow.toml` file to define workspace metadata and runnable tasks.

Example (current supported format):

```toml
[workspace]
name = "my-project"

[tasks]
up = ["npm install"]
build = ["npm run build"]
test = ["npm test"]
```

Each task is defined as an **array of shell commands**.

Clicking a task writes each command sequentially into the live shell.

Example execution:

```
npm install
npm run build
npm test
```

---

# ⚠️ Current Task Format (Important)

The **current Sparrow engine expects tasks defined as arrays**.

Correct:

```toml
[tasks]
test = ["pytest -q"]
```

Not yet supported by the runner:

```toml
[tasks.test]
desc = "Run tests"
cmd = ["pytest -q"]
```

The structured format above is **planned for future releases**.

---

# Example Workspace

Example `sparrow.toml`:

```toml
[workspace]
name = "CopyCat"

[tasks]
up = ["python3 -m pip install -r requirements.txt"]
dev = ["uvicorn app:app --reload --port 8080"]
test = ["pytest -q"]
```

When Sparrow launches it searches upward from the backend working directory until it finds a `sparrow.toml` file.

---

# 🚀 Running Sparrow (Development)

## Prerequisites

Install:

- Node.js 18+
- Rust (stable toolchain)
- Cargo
- Tauri CLI

Install Tauri CLI:

```
cargo install tauri-cli
```

## Install dependencies

```
cd sparrow-app
npm install
```

## Start Sparrow

```
npm run tauri dev
```

This will:

- start the Vite frontend
- compile the Rust backend
- launch the Sparrow desktop window

---

# ⚠️ Important: dev vs tauri dev

Do **NOT** run:

```
npm run dev
```

That command **only starts the Vite dev server**.

It will show something like:

```
Local: http://localhost:1420/
```

but **no Sparrow window will open**.

Always run:

```
npm run tauri dev
```

---

# 🖥 Using Sparrow

1. Launch Sparrow
2. Sparrow locates `sparrow.toml`
3. Sidebar loads workspace name and tasks
4. Click a task to execute it
5. Commands run inside the terminal

You can still type commands manually.

---

# 🎨 UI Features

Current UI includes:

- Dark themed terminal
- Sidebar task runner
- Click‑to‑run commands
- Clear terminal button
- Resizable terminal (xterm + FitAddon)
- Real PTY shell

---

# 🔐 Implementation Notes

Backend:

- Uses `portable-pty` to spawn the shell
- Uses `OnceCell` to store PTY writer state
- Streams output using `tauri::Emitter`
- Parses TOML using `toml` crate

Frontend:

- Uses `xterm.js`
- Uses `FitAddon` for responsive sizing
- Streams PTY output via Tauri events

---

# 🛣 Roadmap

Planned features:

- structured task definitions (`desc`, `cwd`, `cmd`)
- workspace selection UI
- toolchain validation (`[tools]`)
- environment config (`[env]`)
- secret pointers (`[secrets]`)
- service orchestration (`[services]`)
- workspace history
- multi‑workspace support
- Sparrow CLI

---

# 🧩 Philosophy

Sparrow does not try to replace the shell.

Instead it provides **structure around the commands you already run**.

Instead of remembering commands you encode them.

Instead of switching tools you stay in one window.

---

# 📜 License

ISC

