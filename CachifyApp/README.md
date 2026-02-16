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

## Notes for Mac App Store

- This project enables App Sandbox by default.
- Current cleaner logic scans/deletes fixed paths in `~/Library`, which requires additional permission flow for App Store compliance (e.g., user-selected folders + security-scoped bookmarks).
