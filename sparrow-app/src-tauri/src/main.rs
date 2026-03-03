use once_cell::sync::OnceCell;
use portable_pty::{CommandBuilder, NativePtySystem, PtySize, PtySystem};
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use tauri::{Emitter, Window};
use serde::Serialize;
use std::path::{Path, PathBuf};

static PTY_WRITER: OnceCell<Arc<Mutex<Box<dyn Write + Send>>>> = OnceCell::new();

#[tauri::command]
fn spawn_shell(window: Window) -> Result<(), String> {
    let pty_system = NativePtySystem::default();

    let pair = pty_system.openpty(PtySize {
        rows: 24,
        cols: 80,
        pixel_width: 0,
        pixel_height: 0,
    }).map_err(|e| format!("{e}"))?;

    let cmd = CommandBuilder::new("zsh");

    let _child = pair
        .slave
        .spawn_command(cmd)
        .map_err(|e| format!("{e}"))?;

    let mut reader = pair
        .master
        .try_clone_reader()
        .map_err(|e| format!("{e}"))?;

    let writer = pair
        .master
        .take_writer()
        .map_err(|e| format!("{e}"))?;

    let writer = Arc::new(Mutex::new(writer));
    let _ = PTY_WRITER.set(writer.clone());

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

    Ok(())
}

#[tauri::command]
fn pty_write(data: String) -> Result<(), String> {
    if let Some(writer) = PTY_WRITER.get() {
        let mut writer = writer.lock().unwrap();
        writer.write_all(data.as_bytes()).map_err(|e| e.to_string())?;
        let _ = writer.flush();
    }
    Ok(())
}

#[derive(Serialize)]
struct WorkspaceStatus {
    name: String,
    tasks: Vec<String>,
    toml_path: String,
}

fn find_sparrow_toml() -> Result<PathBuf, String> {
    // During dev, current_dir is usually .../sparrow-app/src-tauri
    // So we search upwards until we find sparrow.toml
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

    let cmds = cfg
        .get("tasks")
        .and_then(|t| t.get(&task))
        .and_then(|v| v.as_array())
        .ok_or_else(|| format!("Task not found or not an array: {task}"))?;

    // write a nice header into the terminal
    pty_write(format!("\r\n# sparrow run {task}\r\n"))?;

    for c in cmds {
        let cmd = c
            .as_str()
            .ok_or_else(|| format!("Task '{task}' contains a non-string command"))?;

        // Send command + newline to the shell
        pty_write(cmd.to_string())?;
        pty_write("\n".to_string())?;
    }

    Ok(())
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![spawn_shell, pty_write, get_workspace_status, run_task])
        .run(tauri::generate_context!())
        .expect("error running tauri app");
}