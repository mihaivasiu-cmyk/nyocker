//! Copies the iOS app's spots and venue art into the web UI, so both apps share one source of truth.

use std::fs;
use std::path::Path;

fn main() {
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let data = Path::new(env!("CARGO_MANIFEST_DIR")).join("../web/data");
    fs::create_dir_all(&data).expect("create web/data");

    let files = [
        ("Nyocker/content.json", "content.json"),
        ("Nyocker/discover.json", "discover.json"),
        ("Nyocker/Assets.xcassets/kerge-hero.imageset/kerge-hero.jpg", "kerge-hero.jpg"),
        ("Nyocker/Assets.xcassets/kerge-pin.imageset/kerge-pin.png", "kerge-pin.png"),
        ("Nyocker/Assets.xcassets/underbar.imageset/underbar.png", "underbar.png"),
        ("Nyocker/Assets.xcassets/so.imageset/so.png", "so.png"),
        ("Nyocker/Assets.xcassets/hintalo-hero.imageset/hintalo-hero.jpg", "hintalo-hero.jpg"),
        ("Nyocker/Assets.xcassets/lumen-hero.imageset/lumen-hero.jpg", "lumen-hero.jpg"),
        ("Nyocker/Assets.xcassets/golya-hero.imageset/golya-hero.jpg", "golya-hero.jpg"),
        ("Nyocker/Assets.xcassets/grund-hero.imageset/grund-hero.jpg", "grund-hero.jpg"),
        ("Nyocker/Assets.xcassets/fecske-hero.imageset/fecske-hero.jpg", "fecske-hero.jpg"),
        // Saved copies of the live feeds, shown until the network answers.
        ("docs/news.json", "news.json"),
        ("docs/events.json", "events.json"),
    ];
    for (from, to) in files {
        let from = repo.join(from);
        println!("cargo:rerun-if-changed={}", from.display());
        fs::copy(&from, data.join(to)).unwrap_or_else(|e| panic!("copy {}: {e}", from.display()));
    }

    tauri_build::build();
}
