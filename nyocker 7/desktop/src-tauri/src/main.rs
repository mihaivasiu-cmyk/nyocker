// Nyócker for desktop: the iPhone app's screens in a phone-shaped Tauri window.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{LogicalPosition, LogicalSize, Manager};

/// The iPhone screen the layout is drawn for, in points.
const PHONE: (f64, f64) = (393.0, 852.0);

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            // Fit the phone to the screen: full size where it fits, scaled down on shorter screens
            // (a 13" MacBook has about 750 points of height under the menu bar).
            let window = app.get_webview_window("main").expect("main window");
            if let Some(monitor) = window.current_monitor()? {
                let screen = monitor.size().to_logical::<f64>(monitor.scale_factor());
                let height = (screen.height - 110.0).min(PHONE.1).max(480.0);
                let width = height * PHONE.0 / PHONE.1;
                let origin = monitor.position().to_logical::<f64>(monitor.scale_factor());
                window.set_size(LogicalSize::new(width, height))?;
                window.set_position(LogicalPosition::new(
                    origin.x + (screen.width - width) / 2.0,
                    origin.y + ((screen.height - height) / 2.0).max(30.0),
                ))?;
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running Nyócker");
}
