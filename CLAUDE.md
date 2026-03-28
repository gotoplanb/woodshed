# CLAUDE.md

## Project Overview

Hermit Jam (internal name: Woodshed) is an iOS music practice companion. Import playlists from Apple Music, jam through songs, and practice individual sections with loop and speed control. Edit section timestamps via JSON files in iCloud Drive.

## Build & Deploy

```bash
# Simulator
xcodebuild -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild test -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WoodshedTests

# Device (pass DEVELOPMENT_TEAM via env or flag — never commit to pbxproj)
xcodebuild -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination "id=$DEVICE_UDID" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=$TEAM_ID build
```

## TestFlight Delivery

```bash
cd Woodshed
bundle exec fastlane beta
# Then distribute:
asc builds add-groups --app "$ASC_APP_ID" --latest --group "$TESTFLIGHT_GROUP_ID"
```

Credentials are in `Woodshed/fastlane/.env` (gitignored). See `.env.example` for required vars.

## Key Architecture Decisions

- **iOS 17 minimum**, iPhone + iPad, system appearance
- **Data persistence**: JSON files in iCloud Drive ubiquitous container (`Documents/setlists/*.json`, `Documents/tabs/*.jpg`), local fallback if iCloud unavailable. Uses `NSFileCoordinator` for safe access and `NSMetadataQuery` for remote changes.
- **Dual playback**: MusicKit (`ApplicationMusicPlayer`) for streaming, AVFoundation for local/downloaded tracks with rate control (0.5x/0.75x/1.0x)
- **Playlist import**: Create playlists in Apple Music, import into the app. Edit section timestamps in JSON via iCloud Drive.
- **UI**: Stock SwiftUI components only. No custom design system.
- **Models**: Plain `Codable` structs (no SwiftData). Auto-generate UUIDs when missing from hand-edited JSON.
- **JSON encoding/decoding**: `JSONEncoder.woodshed` / `JSONDecoder.woodshed` extensions with ISO 8601 dates

## Code Conventions

- SwiftUI views use `@Environment` for `StorageService`, `MusicKitService`, `PlaybackCoordinator` (all `@Observable`)
- Models are plain `Codable` structs
- `SongEntry` (not `Song`) to avoid collision with MusicKit's `Song` type
- Swift Testing framework (`@Test`, `@Suite`, `#expect`)
- No third-party dependencies
- No `DEVELOPMENT_TEAM` in project.pbxproj — pass via xcodebuild flags or fastlane .env

## File Layout

```
Woodshed/Woodshed/
├── App/WoodshedApp.swift              # @main, service wiring, About screen on first launch
├── Models/                            # Setlist, SongEntry, Section, AppSettings
├── Storage/StorageService.swift       # JSON persistence + iCloud Drive sync
├── Services/                          # MusicKitService, PlaybackCoordinator, PlaylistImportService
└── Views/                             # SetlistLibrary, SetlistDetail, SongDetail, JamMode, PlaylistPicker, Settings, About, TabImage
```

## Things to Know

- **MusicKit requires App ID registration**: developer.apple.com → Identifiers → App Services → enable MusicKit. This is portal-only, not an Xcode capability.
- **iCloud Drive folder**: visible in Files app as "Hermit Jam" (requires `NSUbiquitousContainers` in Info.plist with `NSUbiquitousContainerIsDocumentScopePublic = true`)
- MusicKit search fails on simulator — use real device for playback testing
- `PRODUCT_NAME` in pbxproj must be `$(TARGET_NAME)`, not empty
- Adding new source files requires manual pbxproj edits (file ref, group, build phase)
- The `Section` model name shadows `SwiftUI.Section` — use `SwiftUI.Section` explicitly in views
- `ApplicationMusicPlayer.shared.playbackTime` must be read directly (not via protocol witness) and Timer must be scheduled on main RunLoop via `DispatchQueue.main.async`
