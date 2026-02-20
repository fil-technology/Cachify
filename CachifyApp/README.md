# CachifyApp

SwiftUI macOS cache cleaner app for development/tooling caches (Xcode, iOS simulators, Node, Python, Android Studio, browsers, Docker, etc.).

This folder is the standalone app project. The root repository can also contain a separate package/CLI implementation.

## AI/LLM Context (Important)

Use this section as quick orientation when a new AI session starts.

### Project goal

- Scan common dev cache directories.
- Let user choose cleanup targets.
- Delete selected cache paths safely.
- Persist reclaimed storage stats.
- Work in App Sandbox/TestFlight via user-selected Home-folder access and security-scoped bookmarks.

### Core architecture

- `App/Sources/App/CachifyApp.swift`
  App entry point.
- `App/Sources/Models/CacheModels.swift`
  Core value types: `CacheTarget`, `ScanEntry`, `TargetSummary`, style model.
- `App/Sources/Data/CacheCatalog.swift`
  Target catalog and path patterns per tool/category.
- `App/Sources/Services/CacheCleaner.swift`
  Scanning, wildcard expansion, size calculation, deletion.
- `App/Sources/Services/FolderAccessManager.swift`
  Sandbox access flow:
  - folder picker (`NSOpenPanel`)
  - bookmark save/load
  - security-scoped access execution wrapper
  - home-folder validation/diagnostics
- `App/Sources/ViewModels/CleanerViewModel.swift`
  App state orchestration, selection, scan/clean flow, stats, diagnostics.
- `App/Sources/Views/ContentView.swift`
  Main screen composition (header, target card, floating action button).
- `App/Sources/Views/Components/*.swift`
  Reusable UI pieces (`ActionArcRing`, `SkeletonBlock`, `TargetCleanupCard`, `TargetInspectorSheet`).

### Current UX behavior

- Main list shows cleanup targets.
- Hovering target row highlights it.
- Clicking target row opens per-target inspector popup:
  - item list with size + path
  - single-item delete
  - select all / deselect all
  - delete selected
- Bottom global "Detected Cache Paths" panel removed in favor of target inspector workflow.

### Sandbox and permissions

- Entitlements are in `App/CachifyApp.entitlements`.
- Required keys:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.files.user-selected.read-write`
  - `com.apple.security.files.bookmarks.app-scope`
- App expects user to grant Home folder once, then restores bookmark on next launches.
- Diagnostics section in UI should be used first when cache detection fails on TestFlight/macOS user machines.

### Known operational notes

- After changing files under `App/Sources`, regenerate/open project as needed.
- `xcodegen generate` can rewrite project metadata; verify entitlements afterward.
- New TestFlight build upload is required for any runtime fix to reach users.

## Setup

### Generate project

```bash
cd /Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp
xcodegen generate
```

### Open in Xcode

```bash
open /Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp/CachifyApp.xcodeproj
```

## App icon setup

1. Provide master PNG (`1024x1024` recommended).
2. Generate all required icon sizes:

```bash
/Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp/Tools/generate_appiconset.sh /absolute/path/to/icon-1024.png
```

Generated output:
`/Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp/App/Assets.xcassets/AppIcon.appiconset`
