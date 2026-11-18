#!/bin/bash
# Build Nyócker for the iOS Simulator and launch it, from the terminal.
# Usage: ./run-sim.sh ["iPhone 16"]
set -euo pipefail
cd "$(dirname "$0")"

DEVICE="${1:-}"
BUNDLE=com.mihaivasiu.nyocker
APP=build/Debug-iphonesimulator/Nyocker.app

if [ -z "$DEVICE" ]; then
  # Newest available iPhone simulator.
  DEVICE=$(xcrun simctl list devices available | grep -E '^\s+iPhone' | tail -1 | sed -E 's/^ +//; s/ \(.*//')
fi
if [ -z "$DEVICE" ]; then
  echo "✗ No iPhone simulator installed. Open Xcode → Settings (Preferences) → Platforms/Components, install iOS, then re-run." >&2
  exit 1
fi
echo "▸ Simulator: $DEVICE"

echo "▸ Building…"
xcodebuild -project Nyocker.xcodeproj -target Nyocker -configuration Debug \
  -sdk iphonesimulator SYMROOT="$PWD/build" CODE_SIGNING_ALLOWED=NO \
  -quiet build

echo "▸ Booting simulator…"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

# Stand in Józsefváros (Blaha Lujza tér) so walking directions work.
xcrun simctl location booted set 47.4963,19.0704 2>/dev/null || true
xcrun simctl privacy booted grant location "$BUNDLE" 2>/dev/null || true

echo "▸ Installing and launching…"
xcrun simctl install booted "$APP"
xcrun simctl terminate booted "$BUNDLE" 2>/dev/null || true
xcrun simctl launch booted "$BUNDLE" -NyockerTab map

echo "✓ Running. To upload to Appetize: (cd build/Debug-iphonesimulator && zip -qr ../../Nyocker-sim.zip Nyocker.app)"
