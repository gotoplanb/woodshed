<img src="woodshed.jpg" alt="Hermit Jam" width="128">

# Hermit Jam

A music practice companion for iOS. Import playlists from Apple Music, jam through songs, and drill individual sections with loop and speed control.

## How It Works

Hermit Jam uses Apple Music for songs and iCloud Drive for setlist data. You create playlists in Apple Music, import them into the app, then edit section timestamps in JSON files. No account, no server, no subscription.

### Quick Start

1. **Create a playlist in Apple Music** with the songs you want to practice
2. **Open Hermit Jam** and tap the import button
3. **Select your playlist** — the app creates a setlist with placeholder sections
4. **Jam** — tap Jam to play through all songs in order
5. **Practice** — tap a song to see its sections, loop any section, adjust speed

### Editing Sections

Section timestamps live in JSON files on iCloud Drive. You can edit them with any text editor.

**Find the files:**
- **iPhone/iPad:** Files app → iCloud Drive → Hermit Jam
- **Mac:** Finder → iCloud Drive → Hermit Jam
- **Terminal:** `~/Library/Mobile Documents/iCloud~com~zeromissionllc~woodshed/Documents/setlists/`

**JSON format:**
```json
{
  "title": "Appetite for Destruction",
  "songs": [
    {
      "title": "Mr. Brownstone",
      "appleMusicID": "1377813295",
      "instrument": "Guitar",
      "sections": [
        { "title": "Intro", "startTime": 0, "endTime": 18, "role": "Rhythm" },
        { "title": "Verse 1", "startTime": 18, "endTime": 60 },
        { "title": "Chorus", "startTime": 60, "endTime": 90 },
        { "title": "Solo", "startTime": 120, "endTime": 155, "role": "Lead", "notes": "Pentatonic run" }
      ]
    }
  ]
}
```

**Fields:**
- `title` — section name (Intro, Verse, Chorus, Solo, etc.)
- `startTime` / `endTime` — seconds into the song
- `role` — optional (Lead, Rhythm, Fill)
- `notes` — optional practice notes
- `instrument` — on the song, not the section (Guitar, Bass, etc.)

You don't need to include `id` fields — the app auto-generates them. Just add songs and sections with titles and timestamps.

**Tips:**
- Listen to the song in Apple Music and note the timestamps
- Start with approximate times, then fine-tune after testing in the app
- Pull down to refresh in the app after editing a JSON file

### Playback Modes

**Jam Mode** — plays songs in order, start to finish. Like Apple Music with your curated setlist. No section boundaries, no seeking, just play.

**Practice Mode** — tap a song to see its sections. The playhead tracks your position. Tap any section to jump to it. Hit the loop button to repeat the current section. Speed control (0.5x, 0.75x, 1x) works with downloaded tracks.

### Speed Control

Speed control requires locally downloaded tracks. Streaming tracks play at normal speed only.

To enable speed control:
1. Purchase the song on iTunes, or buy from the artist and import into your Music library
2. Download it to your device
3. The speed picker will activate automatically

This is intentional — if you want slow practice playback, buy the music. Money goes to the artist.

## Requirements

- iOS 17+
- Apple Music (for song search and streaming playback)
- iCloud (for setlist sync and file editing)

## Building from Source

```bash
# Clone
git clone https://github.com/gotoplanb/woodshed.git
cd woodshed

# Build for simulator
xcodebuild -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run tests
xcodebuild test -project Woodshed/Woodshed.xcodeproj -scheme Woodshed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:WoodshedTests
```

**Note:** MusicKit requires the app's bundle ID to have the MusicKit service enabled at [developer.apple.com](https://developer.apple.com/account/resources/identifiers/). Playback testing requires a real device with an Apple Music subscription.

## Architecture

| Concern | Decision |
|---------|----------|
| Language | Swift, SwiftUI |
| Music | MusicKit (Apple Music) |
| Persistence | JSON files in iCloud Drive |
| Code signing | Xcode automatic signing |
| Testing | Swift Testing framework |
| CI/CD | Fastlane for TestFlight |

## License

Personal use only. See [LICENSE](LICENSE) for details.
