# Nyócker for desktop

The Józsefváros quest map as a desktop app for macOS, Windows and Linux, built with [Tauri 2](https://tauri.app):
a Rust shell around a web interface. It opens in an iPhone-sized window (393 × 852) and copies the iOS app screen for
screen: the start screen with the time-of-day skyline, the map with its spot cards and Discover pages, and the Events,
News and Radio tabs. Colours follow the clock through the same eight phases as `Theme.swift`.

It reads the same spots, Discover pages and venue art as the iOS app. `src-tauri/build.rs` copies `Nyocker/content.json`,
`Nyocker/discover.json`, the Kerge images from the asset catalog and saved copies of the news and events feeds into `web/data/` on every build,
so editing `content.json` updates both apps.

## Run it

You need Rust (`curl https://sh.rustup.rs -sSf | sh`). On Linux also install the WebKit libraries:
`sudo apt install libwebkit2gtk-4.1-dev libsoup-3.0-dev librsvg2-dev`. macOS and Windows 11 need nothing else.

```bash
cargo desktop          # from the repo root: build and open the app
```

## Make an installer

```bash
cargo install tauri-cli --version "^2" --locked   # once
cd desktop/src-tauri
cargo tauri build
```

The `.app` and `.dmg` (macOS), `.msi` and `.exe` (Windows) or `.deb`, `.rpm` and `.AppImage` (Linux) land in
`src-tauri/target/release/bundle/`. Build on each system for its own installer.

## What's inside

| File | What it does |
|---|---|
| `web/index.html`, `style.css` | The iPhone layout and look |
| `web/app.js` | Start screen, map, spot cards, Discover, walking directions, Events, News and Radio tabs |
| `web/vendor/leaflet/` | Leaflet 1.9.4, the map library (BSD-2 licence) |
| `src-tauri/` | The Rust app, window settings and icons |

Map tiles come from OpenStreetMap and walking routes from routing.openstreetmap.de, both free and keyless.
Directions start from your location if the computer shares one in Budapest; otherwise from a blue dot you can drag.
