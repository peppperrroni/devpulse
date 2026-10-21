#!/bin/bash
# Build a Release DevPulse and install it to /Applications (also used to update).
#
# Signs with your first "Apple Development" identity (or DEVPULSE_SIGN_IDENTITY) so
# macOS keeps Full Disk Access across reinstalls; falls back to ad-hoc signing,
# in which case the grant has to be given again after every install.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen > /dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }

identity="${DEVPULSE_SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
    | awk -F'"' '/Apple Development/ { print $2; exit }')}"
sign=(CODE_SIGN_IDENTITY="${identity:--}")
if [[ -n "$identity" ]]; then
    team="$(security find-certificate -c "$identity" -p | openssl x509 -noout -subject \
        | sed -n 's/.*OU *= *\([A-Z0-9]*\).*/\1/p')"
    sign+=(DEVELOPMENT_TEAM="$team")
    echo "Signing with: $identity"
else
    echo "No Apple Development identity found — ad-hoc signing" >&2
fi

xcodegen generate > /dev/null
xcodebuild -quiet -project DevPulse.xcodeproj -scheme DevPulse -configuration Release \
    -derivedDataPath build "${sign[@]}" build

pkill -x DevPulse || true
rm -rf /Applications/DevPulse.app
ditto build/Build/Products/Release/DevPulse.app /Applications/DevPulse.app
open /Applications/DevPulse.app
echo "Installed /Applications/DevPulse.app"
