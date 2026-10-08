# DevPulse

Menu-bar RAM/disk monitor and dev cleaner for this Mac (macOS 26, Apple Silicon).

## Build & run

```bash
brew install xcodegen          # once
xcodegen generate
xcodebuild -project DevPulse.xcodeproj -scheme DevPulse -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/DevPulse.app
```

## Install to /Applications

```bash
scripts/install.sh             # Release build → /Applications/DevPulse.app, relaunches it
```

Run it again to update. Quit with `pkill DevPulse` (no Dock icon, no menu).

## Test

```bash
swift test --package-path Packages/DevPulseCore
```

## Permissions

The first scan of `~` triggers macOS prompts for Desktop/Documents/Downloads and
"access data from other apps" (`~/Library/Containers`). Granting Full Disk Access
(System Settings → Privacy & Security) removes the prompts and the skipped folders.
The app is signed with a stable Apple Development identity so the grant survives rebuilds.
