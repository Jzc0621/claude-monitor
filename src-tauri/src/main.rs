#![windows_subsystem = "windows"]

use serde::{Deserialize, Serialize};
use std::fs;
use std::sync::Arc;
use tauri::Emitter;
use tauri::webview::WebviewWindowBuilder;
use tokio::sync::Mutex;

// ── Gauge state ───────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
struct GaugeData {
    remaining: f64,
    status: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
enum GaugeStatus {
    Idle,
    Normal,
    Critical,
    Compacting,
    Stopped,
}

impl GaugeStatus {
    fn to_str(&self) -> &'static str {
        match self {
            GaugeStatus::Idle => "idle",
            GaugeStatus::Normal => "normal",
            GaugeStatus::Critical => "critical",
            GaugeStatus::Compacting => "compacting",
            GaugeStatus::Stopped => "stopped",
        }
    }
}

struct AppState {
    current_data: Arc<Mutex<GaugeData>>,
}

// ── State file reader ─────────────────────────────────────────────────

fn read_gauge_file() -> Option<GaugeData> {
    let path = std::env::temp_dir().join("claude-context-gauge.json");
    let content = fs::read_to_string(&path).ok()?;
    let data: GaugeData = serde_json::from_str(&content).ok()?;
    Some(data)
}

fn classify_status(data: &GaugeData) -> GaugeStatus {
    match data.status.as_str() {
        "compacting" => GaugeStatus::Compacting,
        "stopped" => GaugeStatus::Stopped,
        _ => {
            if data.remaining > 30.0 {
                GaugeStatus::Normal
            } else {
                GaugeStatus::Critical
            }
        }
    }
}

// ── Tauri commands ────────────────────────────────────────────────────

#[tauri::command]
async fn get_state(s: tauri::State<'_, AppState>) -> Result<serde_json::Value, String> {
    let data = s.current_data.lock().await;
    Ok(serde_json::json!({
        "remaining": data.remaining,
        "status": data.status
    }))
}

// ── Process liveness (simple: check if cc-pid file exists) ────────────

fn is_cc_alive() -> bool {
    // Check if claude-halo or claude Code is still running
    // Halo and CC share the same lifecycle
    let output = std::process::Command::new("tasklist")
        .args(["/FI", "IMAGENAME eq claude-halo.exe"])
        .output();
    if let Ok(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        if stdout.contains("claude-halo.exe") {
            return true;
        }
    }
    // Fallback: check for node.exe (Claude Code runs on Node)
    let output = std::process::Command::new("tasklist")
        .args(["/FI", "IMAGENAME eq node.exe"])
        .output();
    if let Ok(out) = output {
        let stdout = String::from_utf8_lossy(&out.stdout);
        return stdout.matches("node.exe").count() > 2; // multiple node processes = CC likely running
    }
    false
}

// ── Main ──────────────────────────────────────────────────────────────

fn main() {
    let data = Arc::new(Mutex::new(GaugeData {
        remaining: 100.0,
        status: "idle".into(),
    }));
    let data_clone = data.clone();

    tauri::Builder::default()
        .manage(AppState { current_data: data })
        .invoke_handler(tauri::generate_handler![get_state])
        .setup(move |app| {
            let window = WebviewWindowBuilder::new(app, "main",
                tauri::WebviewUrl::App("index.html".into())
            )
            .title("Context Gauge")
            .inner_size(80.0, 80.0)
            .resizable(false)
            .decorations(false)
            .transparent(true)
            .always_on_top(true)
            .skip_taskbar(true)
            .shadow(false)
            .initialization_script("document.documentElement.style.setProperty('background','transparent','important');document.body.style.setProperty('background','transparent','important');")
            .build()?;

            // Mouse passthrough
            let _ = window.set_ignore_cursor_events(true);

            // Position at bottom-right, above Halo if present
            // Halo is at: y = screen_height - 100 - 140, x = screen_width - 100 - 28
            // Gauge goes above Halo: same x, y = halo_y - 90
            if let Ok(Some(monitor)) = window.primary_monitor() {
                let m = monitor.size();
                let ws = window.outer_size().unwrap();
                let x = (m.width as i32 - ws.width as i32 - 28).max(0);
                let y = (m.height as i32 - ws.height as i32 - 240).max(0);
                let _ = window.set_position(tauri::Position::Physical(
                    tauri::PhysicalPosition::new(x, y)
                ));
            }

            let win = window.clone();
            let st = data_clone;

            tauri::async_runtime::spawn(async move {
                let mut interval = tokio::time::interval(tokio::time::Duration::from_millis(150));
                let mut alive_check_ticks: u32 = 0;
                let mut displayed_status: Option<GaugeStatus> = None;
                let mut displayed_remaining: Option<f64> = None;

                loop {
                    interval.tick().await;

                    // ── Process liveness check (every ~2.25 s) ──
                    if alive_check_ticks == 0 {
                        if !is_cc_alive() {
                            let _ = win.close();
                            break;
                        }
                        alive_check_ticks = 15;
                    }
                    alive_check_ticks -= 1;

                    // ── Read gauge file ──────────────────────
                    let gauge_data = read_gauge_file().unwrap_or(GaugeData {
                        remaining: 100.0,
                        status: "idle".into(),
                    });

                    let new_status = classify_status(&gauge_data);

                    // Emit if changed
                    let status_changed = displayed_status != Some(new_status);
                    let remaining_changed = displayed_remaining.map_or(true, |r| {
                        (r - gauge_data.remaining).abs() > 0.5
                    });

                    if status_changed || remaining_changed {
                        let _ = win.emit("state-changed", serde_json::json!({
                            "remaining": gauge_data.remaining,
                            "status": new_status.to_str()
                        }));
                        displayed_remaining = Some(gauge_data.remaining);
                        *st.lock().await = gauge_data;
                        displayed_status = Some(new_status);
                    }
                }
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error");
}
