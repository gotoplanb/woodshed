# CLAUDE.md

## Project Overview

Woodshed is an iOS music practice companion. It plays sections of Apple Music tracks with tab images displayed, auto-advances through a setlist, and supports loop/speed control for focused practice.

## Build & Deploy

```bash
# Simulator
xcodebuild -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild test -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WoodshedTests

# Device — Beta iPhone 15 Pro (connected to Mac mini, for dev testing)
xcodebuild -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination 'id=00008130-000139A00AC2001C' \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device 65000D11-CB21-5CC1-9D0F-3C2B85EDA5FE \
  ~/Library/Developer/Xcode/DerivedData/Woodshed-*/Build/Products/Debug-iphoneos/Woodshed.app
xcrun devicectl device process launch --device 65000D11-CB21-5CC1-9D0F-3C2B85EDA5FE com.zeromissionllc.woodshed
```

## Key Architecture Decisions

- **iOS 17 minimum**, iPhone + iPad, system appearance
- **Data persistence**: JSON files in iCloud Drive ubiquitous container (`Documents/setlists/*.json`, `Documents/tabs/*.jpg`), local fallback if iCloud unavailable. Uses `NSFileCoordinator` for safe access and `NSMetadataQuery` for remote changes.
- **Dual playback**: MusicKit (`ApplicationMusicPlayer`) for streaming, AVFoundation for local/downloaded tracks with rate control (0.5x/0.75x/1.0x)
- **UI**: Stock SwiftUI components only. No custom design system.
- **Models**: Plain `Codable` structs (no SwiftData)
- **JSON encoding/decoding**: `JSONEncoder.woodshed` / `JSONDecoder.woodshed` extensions with ISO 8601 dates

## Code Conventions

- SwiftUI views use `@Environment` for `StorageService`, `MusicKitService`, `PlaybackCoordinator` (all `@Observable`)
- Models are plain `Codable` structs
- Swift Testing framework (`@Test`, `@Suite`, `#expect`)
- No third-party dependencies
- No `DEVELOPMENT_TEAM` in project.pbxproj — pass via xcodebuild flags

## File Layout

```
Woodshed/Woodshed/
├── App/WoodshedApp.swift           # @main, service wiring
├── Models/                         # Setlist, Section, AppSettings
├── Storage/StorageService.swift    # JSON persistence + iCloud Drive sync
├── Services/                       # MusicKitService, PlaybackCoordinator
└── Views/                          # All SwiftUI views
```

## Things to Know

- MusicKit search fails on simulator — use real device for playback testing
- `PRODUCT_NAME` in pbxproj must be `$(TARGET_NAME)`, not empty
- `UILaunchScreen` dict must exist in Info.plist
- Adding new source files requires manual pbxproj edits (file ref, group, build phase)
- The `Section` model name shadows `SwiftUI.Section` — use `SwiftUI.Section` explicitly in views
