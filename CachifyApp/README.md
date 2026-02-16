# CachifyApp (Xcode Project)

Standalone macOS app project generated separately from the Swift package.

## Generate the project

```bash
cd /Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp
xcodegen generate
```

## Open in Xcode

```bash
open /Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp/CachifyApp.xcodeproj
```

## App icon setup

1. Put your master icon PNG (recommended `1024x1024`) anywhere.
2. Generate all required macOS icon sizes:

```bash
/Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp/Tools/generate_appiconset.sh /absolute/path/to/icon-1024.png
```

This writes icons into:
`/Users/sviatoslavfil/Development/Fil.Technology/MacOS/Cachify/Source/CachifyApp/App/Assets.xcassets/AppIcon.appiconset`

The project already uses `AppIcon` as the app icon set name.

## Notes for Mac App Store

- This project enables App Sandbox by default.
- Current cleaner logic scans/deletes fixed paths in `~/Library`, which requires additional permission flow for App Store compliance (e.g., user-selected folders + security-scoped bookmarks).
