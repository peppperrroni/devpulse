#!/bin/bash
# Build a Release DevPulse and install it to /Applications (also used to update).
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate > /dev/null
xcodebuild -quiet -project DevPulse.xcodeproj -scheme DevPulse -configuration Release \
    -derivedDataPath build build

pkill -x DevPulse || true
rm -rf /Applications/DevPulse.app
ditto build/Build/Products/Release/DevPulse.app /Applications/DevPulse.app
open /Applications/DevPulse.app
echo "Installed /Applications/DevPulse.app"
