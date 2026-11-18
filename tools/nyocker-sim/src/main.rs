//! `cargo sim`: build Nyócker and run it in the iOS Simulator, from the terminal.
//!
//! It drives Apple's own tools (`xcodebuild`, `xcrun simctl`), so it needs a Mac with Xcode.

use std::env;
use std::path::{Path, PathBuf};
use std::process::{exit, Command, Stdio};

const BUNDLE: &str = "com.mihaivasiu.nyocker";
/// Blaha Lujza tér, so walking directions to Józsefváros spots work.
const HOME: &str = "47.4963,19.0704";

const HELP: &str = "\
cargo sim [command] [options]

Commands:
  run       Build, install and launch in the Simulator (default)
  build     Only build the app
  zip       Build and zip the app for Appetize (Nyocker-sim.zip)
  devices   List the iPhone simulators you can use

Options:
  -d, --device NAME   Simulator to use, e.g. \"iPhone 16\" (default: newest iPhone)
  -l, --location LAT,LON  Where the Simulator stands (default: Blaha Lujza tér)
  -t, --tab TAB       Tab to open: map, events, news, radio (default: map)
  -h, --help          Show this help";

struct Options {
    command: String,
    device: Option<String>,
    location: String,
    tab: String,
}

fn main() {
    let options = parse(env::args().skip(1).collect());
    if cfg!(not(target_os = "macos")) {
        fail("this needs macOS with Xcode installed: the iOS Simulator only runs on a Mac");
    }
    let root = project_root();

    match options.command.as_str() {
        "devices" => {
            for (name, udid, state) in iphones() {
                println!("{name}  ({state})  {udid}");
            }
        }
        "build" => {
            build(&root);
        }
        "zip" => {
            let app = build(&root);
            let zip = root.join("Nyocker-sim.zip");
            let _ = std::fs::remove_file(&zip);
            step("Zipping for Appetize");
            run(Command::new("zip").arg("-qr").arg(&zip).arg("Nyocker.app")
                .current_dir(app.parent().unwrap()));
            done(&format!("upload {} to appetize.io", zip.display()));
        }
        "run" => {
            let app = build(&root);
            launch(&app, &options);
        }
        other => fail(&format!("unknown command `{other}`\n\n{HELP}")),
    }
}

fn parse(args: Vec<String>) -> Options {
    let mut options = Options {
        command: "run".into(),
        device: None,
        location: HOME.into(),
        tab: "map".into(),
    };
    let mut args = args.into_iter();
    while let Some(arg) = args.next() {
        let mut value = |flag: &str| args.next().unwrap_or_else(|| fail(&format!("{flag} needs a value")));
        match arg.as_str() {
            "-h" | "--help" => {
                println!("{HELP}");
                exit(0);
            }
            "-d" | "--device" => options.device = Some(value(&arg)),
            "-l" | "--location" => options.location = value(&arg),
            "-t" | "--tab" => options.tab = value(&arg),
            "run" | "build" | "zip" | "devices" => options.command = arg,
            other => fail(&format!("unknown argument `{other}`\n\n{HELP}")),
        }
    }
    if !["map", "events", "news", "radio"].contains(&options.tab.as_str()) {
        fail("--tab must be one of map, events, news, radio");
    }
    options
}

/// The folder holding Nyocker.xcodeproj, found by walking up from here.
fn project_root() -> PathBuf {
    let mut dir = env::current_dir().expect("current folder");
    loop {
        if dir.join("Nyocker.xcodeproj").is_dir() {
            return dir;
        }
        if !dir.pop() {
            fail("can't find Nyocker.xcodeproj: run this inside the nyocker repo");
        }
    }
}

fn build(root: &Path) -> PathBuf {
    step("Building Nyócker for the Simulator");
    let symroot = root.join("build");
    run(Command::new("xcodebuild")
        .args(["-project", "Nyocker.xcodeproj", "-target", "Nyocker", "-configuration", "Debug"])
        .args(["-sdk", "iphonesimulator", "CODE_SIGNING_ALLOWED=NO", "-quiet", "build"])
        .arg(format!("SYMROOT={}", symroot.display()))
        .current_dir(root));
    let app = symroot.join("Debug-iphonesimulator/Nyocker.app");
    if !app.is_dir() {
        fail(&format!("build finished but {} is missing", app.display()));
    }
    app
}

fn launch(app: &Path, options: &Options) {
    let phones = iphones();
    let (name, udid, state) = match &options.device {
        Some(wanted) => phones.into_iter().find(|(name, ..)| name == wanted)
            .unwrap_or_else(|| fail(&format!("no simulator called \"{wanted}\" (see `cargo sim devices`)"))),
        None => phones.into_iter().last()
            .unwrap_or_else(|| fail("no iPhone simulators installed: add one in Xcode → Settings → Platforms")),
    };

    step(&format!("Starting {name}"));
    if state != "Booted" {
        run(Command::new("xcrun").args(["simctl", "boot", &udid]));
    }
    quiet(Command::new("open").args(["-a", "Simulator"]));
    quiet(Command::new("xcrun").args(["simctl", "location", &udid, "set", &options.location]));
    quiet(Command::new("xcrun").args(["simctl", "privacy", &udid, "grant", "location", BUNDLE]));

    step("Installing and launching");
    run(Command::new("xcrun").args(["simctl", "install", &udid]).arg(app));
    quiet(Command::new("xcrun").args(["simctl", "terminate", &udid, BUNDLE]));
    run(Command::new("xcrun").args(["simctl", "launch", &udid, BUNDLE, "-NyockerTab", &options.tab]));
    done(&format!("Nyócker is running on {name}, standing at {}", options.location));
}

/// Available iPhone simulators as (name, udid, state), oldest runtime first.
fn iphones() -> Vec<(String, String, String)> {
    let output = Command::new("xcrun").args(["simctl", "list", "devices", "available"])
        .output().unwrap_or_else(|_| fail("can't run xcrun: is Xcode installed?"));
    String::from_utf8_lossy(&output.stdout).lines().filter_map(device_line).collect()
}

/// Reads a line like `    iPhone 16 (1A2B…-…) (Shutdown) `.
fn device_line(line: &str) -> Option<(String, String, String)> {
    let line = line.trim();
    if !line.starts_with("iPhone") {
        return None;
    }
    let state_open = line.rfind(" (")?;
    let state = line[state_open + 2..].trim_end_matches(')').to_string();
    let rest = &line[..state_open];
    let udid_open = rest.rfind(" (")?;
    let udid = rest[udid_open + 2..].trim_end_matches(')').to_string();
    Some((rest[..udid_open].to_string(), udid, state))
}

fn run(command: &mut Command) {
    let status = command.status().unwrap_or_else(|e| fail(&format!("can't start {command:?}: {e}")));
    if !status.success() {
        fail(&format!("{:?} failed ({status})", command.get_program()));
    }
}

/// For steps that may fail harmlessly, like stopping an app that isn't running.
fn quiet(command: &mut Command) {
    let _ = command.stdout(Stdio::null()).stderr(Stdio::null()).status();
}

fn step(text: &str) {
    println!("▸ {text}…");
}

fn done(text: &str) {
    println!("✓ {text}");
}

fn fail(text: &str) -> ! {
    eprintln!("✗ {text}");
    exit(1);
}

#[cfg(test)]
mod tests {
    use super::device_line;

    #[test]
    fn reads_simulator_lines() {
        let line = "    iPhone 16 Pro (5B0C3E2A-1111-2222-3333-444455556666) (Booted) ";
        assert_eq!(device_line(line), Some((
            "iPhone 16 Pro".into(),
            "5B0C3E2A-1111-2222-3333-444455556666".into(),
            "Booted".into(),
        )));
        assert_eq!(device_line("-- iOS 18.0 --"), None);
        assert_eq!(device_line("    iPad Air (ABC) (Shutdown)"), None);
    }
}
