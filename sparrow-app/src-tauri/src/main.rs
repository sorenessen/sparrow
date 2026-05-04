use once_cell::sync::OnceCell;
use portable_pty::{CommandBuilder, MasterPty, NativePtySystem, PtySize, PtySystem};
use serde::Serialize;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use tauri::{Emitter, Window};

static PTY_WRITER: OnceCell<Arc<Mutex<Box<dyn Write + Send>>>> = OnceCell::new();
static PTY_MASTER: OnceCell<Arc<Mutex<Box<dyn MasterPty + Send>>>> = OnceCell::new();

static WORKSPACE_ROOT: OnceCell<Arc<Mutex<Option<PathBuf>>>> = OnceCell::new();

fn workspace_root() -> Arc<Mutex<Option<PathBuf>>> {
    WORKSPACE_ROOT
        .get_or_init(|| Arc::new(Mutex::new(None)))
        .clone()
}

#[tauri::command]
fn spawn_shell(window: Window) -> Result<(), String> {
    let pty_system = NativePtySystem::default();

    // Create with a sensible default size; the frontend will call pty_resize() immediately.
    let pair = pty_system
        .openpty(PtySize {
            rows: 24,
            cols: 80,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| format!("{e}"))?;

    let mut cmd = CommandBuilder::new("zsh");
    cmd.arg("-ic");
    cmd.arg("source /Users/sorenessen/Projects/sparrow/sparrow-app/src-tauri/resources/pilar.zsh && pilar; exec zsh -i");
    cmd.env("TERM", "xterm-256color");
    cmd.env("COLORTERM", "truecolor");
    cmd.env("LANG", "en_US.UTF-8");

    let _child = pair
        .slave
        .spawn_command(cmd)
        .map_err(|e| format!("{e}"))?;

    // Keep the MasterPty around for resize.
    let mut master = pair.master;

    let mut reader = master
        .try_clone_reader()
        .map_err(|e| format!("{e}"))?;

    let writer = master.take_writer().map_err(|e| format!("{e}"))?;

    let writer = Arc::new(Mutex::new(writer));
    let _ = PTY_WRITER.set(writer.clone());

    let master = Arc::new(Mutex::new(master));
    let _ = PTY_MASTER.set(master.clone());

    std::thread::spawn(move || {
        let mut buffer = [0u8; 4096];
        loop {
            match reader.read(&mut buffer) {
                Ok(0) => break,
                Ok(n) => {
                    let text = String::from_utf8_lossy(&buffer[..n]).to_string();
                    let _ = window.emit("pty_output", text);
                }
                Err(_) => break,
            }
        }
    });

    // pty_write("source ./resources/pilar.zsh\npilar\n".to_string())?;

    Ok(())
}

#[tauri::command]
fn pty_write(data: String) -> Result<(), String> {
    if let Some(writer) = PTY_WRITER.get() {
        let mut writer = writer.lock().map_err(|_| "PTY writer lock poisoned".to_string())?;
        writer
            .write_all(data.as_bytes())
            .map_err(|e| e.to_string())?;
        let _ = writer.flush();
    }
    Ok(())
}

#[tauri::command]
fn pty_resize(cols: u16, rows: u16) -> Result<(), String> {
    let master = PTY_MASTER
        .get()
        .ok_or_else(|| "PTY not started yet".to_string())?;

    let mut master = master
        .lock()
        .map_err(|_| "PTY master lock poisoned".to_string())?;

    master
        .resize(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[derive(Serialize)]
struct WorkspaceStatus {
    name: String,
    tasks: Vec<String>,
    toml_path: String,
}

fn find_sparrow_toml() -> Result<PathBuf, String> {
    // 1) If user selected a workspace root, use it
    if let Ok(lock) = workspace_root().lock() {
        if let Some(root) = lock.as_ref() {
            let candidate = root.join("sparrow.toml");
            if candidate.exists() {
                return Ok(candidate);
            }
            return Err(format!("No sparrow.toml found in selected workspace: {}", root.display()));
        }
    }

    // 2) Fallback: search upwards from current dir (dev convenience)
    let mut cur = std::env::current_dir().map_err(|e| e.to_string())?;
    loop {
        let candidate = cur.join("sparrow.toml");
        if candidate.exists() {
            return Ok(candidate);
        }
        if !cur.pop() {
            break;
        }
    }

    Err("sparrow.toml not found (searched upwards from current dir)".into())
}

fn load_sparrow_toml() -> Result<toml::Value, String> {
    let path = find_sparrow_toml()?;
    let text = std::fs::read_to_string(&path).map_err(|e| e.to_string())?;
    text.parse::<toml::Value>().map_err(|e| e.to_string())
}

#[tauri::command]
fn get_workspace_status() -> Result<WorkspaceStatus, String> {
    let path = find_sparrow_toml()?;
    let cfg = load_sparrow_toml()?;

    let name = cfg
        .get("workspace")
        .and_then(|w| w.get("name"))
        .and_then(|v| v.as_str())
        .unwrap_or("workspace")
        .to_string();

    let tasks = cfg
        .get("tasks")
        .and_then(|t| t.as_table())
        .map(|tbl| tbl.keys().cloned().collect::<Vec<_>>())
        .unwrap_or_default();

    Ok(WorkspaceStatus {
        name,
        tasks,
        toml_path: path.to_string_lossy().to_string(),
    })
}

#[tauri::command]
fn run_task(task: String) -> Result<(), String> {
    let cfg = load_sparrow_toml()?;

    // cd into selected workspace root if set
    if let Ok(lock) = workspace_root().lock() {
        if let Some(root) = lock.as_ref() {
            pty_write(format!("cd \"{}\"\n", root.to_string_lossy()))?;
        }
    }

    let resolved = match task_commands(&cfg, &task) {
        Ok(r) => r,
        Err(e) => {
            let _ = pty_write(format!("\r\n# sparrow error: {e}\r\n"));
            return Err(e);
        }
    };

    let _ = pty_write(format!("\r\n# sparrow run {task}\r\n"));

    // If the task specifies cwd, cd into it relative to workspace root (already cd'd above)
    if let Some(subdir) = resolved.cwd.as_deref() {
        let safe = subdir.replace('"', "\\\"");
        let _ = pty_write(format!("cd \"{}\"\n", safe));
    }

    for cmd in resolved.commands {
        let _ = pty_write(cmd);
        let _ = pty_write("\n".to_string());
    }

    // Optional: reset back to workspace root after running a task with cwd
    if resolved.cwd.is_some() {
        if let Ok(lock) = workspace_root().lock() {
            if let Some(root) = lock.as_ref() {
                let _ = pty_write(format!("cd \"{}\"\n", root.to_string_lossy()));
            }
        }
    }

    Ok(())
}

#[tauri::command]
fn set_workspace(path: String) -> Result<WorkspaceStatus, String> {
    let root = PathBuf::from(path);
    if !root.exists() {
        return Err("Workspace path does not exist".into());
    }
    if !root.is_dir() {
        return Err("Workspace path is not a directory".into());
    }

    let toml_path = root.join("sparrow.toml");
    if !toml_path.exists() {
        return Err("No sparrow.toml in that directory".into());
    }

    *workspace_root()
        .lock()
        .map_err(|_| "Workspace lock poisoned".to_string())? = Some(root);

    get_workspace_status()
}

/* ------------------------- task parsing + argv support ------------------------- */

#[derive(Debug)]
struct ResolvedTask {
    cwd: Option<String>,
    commands: Vec<String>, // shell lines to run
}

fn shell_escape(s: &str) -> String {
    if s.is_empty() {
        return "''".to_string();
    }
    // If it's "simple", don't quote
    let simple = s.chars().all(|c| c.is_ascii_alphanumeric() || "-._/:@".contains(c));
    if simple {
        return s.to_string();
    }
    // Single-quote escape: ' -> '\'' for POSIX shells
    format!("'{}'", s.replace('\'', "'\\''"))
}

fn argv_to_shell(argv: &[toml::Value]) -> Result<String, String> {
    let mut parts = Vec::new();
    for v in argv {
        let s = v
            .as_str()
            .ok_or_else(|| "cmd argv must be an array of strings".to_string())?;
        parts.push(shell_escape(s));
    }
    Ok(parts.join(" "))
}

fn task_commands(cfg: &toml::Value, task: &str) -> Result<ResolvedTask, String> {
    let tasks = cfg
        .get("tasks")
        .ok_or_else(|| "Missing [tasks] in sparrow.toml".to_string())?;

    let v = tasks
        .get(task)
        .ok_or_else(|| format!("Task not found: {task}"))?;

    // Allow simple legacy forms too:
    // dev = "npm run dev"
    if let Some(s) = v.as_str() {
        return Ok(ResolvedTask {
            cwd: None,
            commands: vec![s.to_string()],
        });
    }

    // dev = ["cmd1", "cmd2"] (array of shell lines)
    if let Some(arr) = v.as_array() {
        let mut out = Vec::new();
        for item in arr {
            let s = item
                .as_str()
                .ok_or_else(|| format!("Task '{task}' array must contain only strings"))?;
            out.push(s.to_string());
        }
        return Ok(ResolvedTask {
            cwd: None,
            commands: out,
        });
    }

    // Table forms:
    // [tasks.dev]
    // desc = "..."
    // cwd = "frontend" (optional)
    // cmd = "uvicorn app:app ..." OR cmd = ["uvicorn","app:app","--reload"]
    if let Some(t) = v.as_table() {
        let cwd = t.get("cwd").and_then(|x| x.as_str()).map(|s| s.to_string());

        // Primary key: cmd (string or argv array)
        if let Some(cmdv) = t.get("cmd") {
            if let Some(s) = cmdv.as_str() {
                return Ok(ResolvedTask {
                    cwd,
                    commands: vec![s.to_string()],
                });
            }
            if let Some(argv) = cmdv.as_array() {
                let line = argv_to_shell(argv)?;
                return Ok(ResolvedTask {
                    cwd,
                    commands: vec![line],
                });
            }
            return Err(format!("Task '{task}'.cmd must be a string or array of strings"));
        }

        // Aliases (string only)
        for key in ["run", "command", "script", "exec"] {
            if let Some(s) = t.get(key).and_then(|x| x.as_str()) {
                return Ok(ResolvedTask {
                    cwd,
                    commands: vec![s.to_string()],
                });
            }
        }

        // Multi-step arrays (optional): strings or argv arrays
        for key in ["cmds", "commands", "steps", "scripts"] {
            if let Some(arr) = t.get(key).and_then(|x| x.as_array()) {
                let mut out = Vec::new();
                for item in arr {
                    if let Some(s) = item.as_str() {
                        out.push(s.to_string());
                        continue;
                    }
                    if let Some(argv) = item.as_array() {
                        out.push(argv_to_shell(argv)?);
                        continue;
                    }
                    return Err(format!("Task '{task}' {key} items must be string or argv array"));
                }
                return Ok(ResolvedTask { cwd, commands: out });
            }
        }

        let keys: Vec<String> = t.keys().cloned().collect();
        return Err(format!(
            "Task '{task}' table keys not recognized. Found keys: {}",
            keys.join(", ")
        ));
    }

    Err(format!(
        "Task '{task}' must be a string, an array, or a table in sparrow.toml"
    ))
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            spawn_shell,
            pty_write,
            pty_resize,
            get_workspace_status,
            run_task,
            set_workspace
        ])
        .run(tauri::generate_context!())
        .expect("error running tauri app");
}