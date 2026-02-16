# Cachify (SwiftUI macOS app)

Cachify is a SwiftUI desktop app for cleaning developer caches on macOS.

Focus areas:
- Xcode / iOS Simulator
- Node.js (npm, Yarn, pnpm, bun)
- Python (pip, Poetry, PDM, uv)
- Android Studio
- Build tools (CocoaPods, Carthage, Homebrew)

## Run

### Option 1: Xcode (recommended)

1. Open `/Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/Package.swift` in Xcode.
2. Select the `cachify` scheme.
3. Run.

### Option 2: Terminal

```bash
cd /Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source
swift run
```

## What the app does

- Lets you select cache targets with checkboxes.
- Scans and shows reclaimable size per cache path.
- Confirms before cleanup.
- Re-scans after cleanup.

## Safety model

- Deletes only paths under your user home directory.
- Skips missing paths automatically.
- Never deletes your home directory root.
