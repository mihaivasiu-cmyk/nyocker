#!/bin/bash
# Archive Nyócker and upload it to TestFlight.
# Needs Xcode 26+ (App Store Connect rejects older builds) and an App Store Connect API key:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (path to AuthKey_XXXX.p8)
# Optional: BUILD_NUMBER (defaults to a timestamp so every upload is unique).
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}" "${ASC_KEY_PATH:?set ASC_KEY_PATH}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%y%m%d%H%M)}"
OUT="$PWD/build/testflight"
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

major=$(xcodebuild -version | awk 'NR==1{split($2,v,"."); print v[1]}')
if [ "$major" -lt 26 ]; then
  echo "✗ $(xcodebuild -version | head -1): App Store Connect only accepts builds from Xcode 26 or later." >&2
  exit 1
fi

rm -rf "$OUT" && mkdir -p "$OUT"
echo "▸ Archiving build ${BUILD_NUMBER}…"
xcodebuild -project Nyocker.xcodeproj -scheme Nyocker -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Nyocker.xcarchive" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" "${AUTH[@]}" -quiet archive

echo "▸ Uploading to App Store Connect…"
xcodebuild -exportArchive -archivePath "$OUT/Nyocker.xcarchive" \
  -exportOptionsPlist ExportOptions.plist -exportPath "$OUT" "${AUTH[@]}"

echo "✓ Uploaded build ${BUILD_NUMBER}. It shows up in App Store Connect → TestFlight after processing (5–30 min)."
