use once_cell::sync::OnceCell;
use portable_pty::{CommandBuilder, NativePtySystem, PtySize, PtySystem};
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use tauri::{Emitter, Window};

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

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![spawn_shell, pty_write])
        .run(tauri::generate_context!())
        .expect("error running tauri app");
}