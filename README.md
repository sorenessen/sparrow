
# 🕊 Sparrow

Sparrow is a desktop workspace runner built with **Tauri + Rust + TypeScript**.

It combines a real PTY-backed system shell with a sidebar task runner powered by a `sparrow.toml` configuration file.

The goal is simple:

**Turn the commands you already run in a terminal into reproducible, one-click tasks.**

---

# Table of Contents

1. Overview
2. What Sparrow Is
3. Architecture
4. Project Structure
5. Running Sparrow (Development)
6. Using Sparrow
7. sparrow.toml Configuration
8. Current Task Format (Important)
9. UI Features
10. Implementation Notes
11. Troubleshooting
12. Roadmap
13. Philosophy
14. License

---

# Overview

Sparrow provides:

• a real interactive terminal  
• a workspace-aware task runner  
• a minimal UI for executing project workflows  

Instead of remembering commands or switching between scripts, you encode them in `sparrow.toml` and execute them directly from Sparrow.

---

# What Sparrow Is

Sparrow is:

• a real terminal (PTY shell)  
• a lightweight task runner  
• a desktop developer utility  
• a workflow orchestration layer

Sparrow is **not**:

• a replacement for your shell  
• a package manager  
• a heavy build tool

It is intentionally thin and sits on top of the tools you already use.

---

# Architecture

Sparrow has two primary layers.

## Rust Backend (Tauri)

The backend is responsible for interacting with the system shell.

Responsibilities:

• Spawn a PTY (pseudo terminal)  
• Launch the user's shell (`zsh`, `bash`, etc.)  
• Stream terminal output to the frontend  
• Accept keyboard input from the UI  
• Parse `sparrow.toml`  
• Discover available tasks  
• Execute tasks by writing commands into the shell

Key Rust components:

• `portable-pty` – PTY creation and management  
• `tauri` – desktop application framework  
• `serde` – serialization  
• `toml` – configuration parsing  
• `OnceCell` – persistent PTY writer storage

Execution flow:

1. Sparrow launches and spawns a PTY shell
2. The backend searches upward for `sparrow.toml`
3. Tasks are parsed from the TOML file
4. Tasks are sent to the frontend
5. Clicking a task writes commands into the shell
6. Shell output streams back to the UI

This design ensures Sparrow behaves exactly like a normal terminal session.

## TypeScript Frontend

The frontend renders the terminal UI and sidebar.

Built with:

• Vite  
• xterm.js  
• xterm FitAddon

Responsibilities:

• Render a real terminal interface  
• Display the task sidebar  
• Send commands to the backend  
• Receive shell output events  
• Maintain terminal sizing

Terminal resizing uses the FitAddon so the PTY dimensions stay synchronized with the UI.

---

# Project Structure

```
sparrow/
├── sparrow.toml
├── sparrow-app/
│   ├── src/
│   │   ├── main.ts
│   │   └── styles.css
│   │
│   ├── src-tauri/
│   │   └── main.rs
│   │
│   ├── index.html
│   └── package.json
└── README.md
```

---

# Running Sparrow (Development)

## Prerequisites

Install:

• Node.js 18+  
• Rust (stable toolchain)  
• Cargo  
• Tauri CLI

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

This command:

1. launches the Vite frontend
2. compiles the Rust backend
3. opens the Sparrow desktop window

---

# Important: dev vs tauri dev

Do NOT run:

```
npm run dev
```

This only launches the Vite development server and **does not start the Sparrow application.**

Always run:

```
npm run tauri dev
```

---

# Using Sparrow

1. Launch Sparrow
2. Sparrow searches for `sparrow.toml`
3. Workspace name appears in the sidebar
4. Tasks populate the sidebar
5. Click a task to run it

Tasks execute inside the live terminal session.

You can also type commands manually.

---

# sparrow.toml Configuration

Example configuration:

```
[workspace]
name = "my-project"

[tasks]
up = ["npm install"]
build = ["npm run build"]
test = ["npm test"]
```

Each task is defined as an **array of shell commands**.

Commands execute sequentially inside the terminal.

Example execution:

```
npm install
npm run build
npm test
```

---

# Current Task Format (Important)

The **current Sparrow runner only supports array-based task definitions.**

Correct:

```
[tasks]
test = ["pytest -q"]
```

Not yet supported by the current runner:

```
[tasks.test]
desc = "Run tests"
cmd = ["pytest -q"]
```

The structured format above is planned for future versions of Sparrow.

---

# UI Features

The current Sparrow interface includes:

• Embedded terminal (xterm.js)  
• Sidebar task runner  
• Click-to-run commands  
• Clear terminal button  
• Responsive terminal resizing  
• Real PTY shell execution

---

# Implementation Notes

Backend:

• PTY spawned with `portable-pty`  
• PTY writer stored using `OnceCell`  
• Shell output streamed via `tauri::Emitter`  
• TOML parsed using `toml` crate

Frontend:

• `xterm.js` terminal rendering  
• `FitAddon` for terminal resizing  
• events streamed via Tauri

---

# Troubleshooting

## Sparrow window does not open

Most likely you ran the wrong command.

Correct:

```
npm run tauri dev
```

Incorrect:

```
npm run dev
```

---

## Tasks do not appear

Sparrow could not find a `sparrow.toml` file.

Ensure the file exists somewhere above the backend working directory.

---

## Task error: "not an array"

Tasks must currently be arrays:

Correct:

```
[tasks]
test = ["pytest -q"]
```

---

# Roadmap

Planned improvements:

• structured task definitions (`desc`, `cwd`, `cmd`)  
• workspace selection UI  
• toolchain validation (`[tools]`)  
• environment configuration (`[env]`)  
• secret references (`[secrets]`)  
• service orchestration (`[services]`)  
• workspace history  
• multi-workspace support  
• Sparrow CLI

---

# Philosophy

Sparrow embraces the shell.

Instead of replacing it, Sparrow gives structure to repetition.

Commands you run frequently become tasks.  
Tasks become reproducible workflows.

---

# License

ISC
