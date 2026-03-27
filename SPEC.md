# Woodshed — Project Specification

## Overview

Woodshed is a personal music practice companion for iOS. It solves one specific problem: the friction of stopping, scrubbing to the right timestamp, and finding the right tab or sheet music every time you want to practice a specific section of a song.

The app lets you define a **setlist** — a sequence of song sections, each with a timestamp range tied to the Apple Music track and an attached tab image. You hit play, the app plays that section of the real song, shows you the tab, and auto-advances to the next section when done. Practice becomes a guided, uninterrupted flow.

The primary use case for v1 is a single user (the developer) learning songs from the Guns N' Roses *Appetite for Destruction* songbook, using scanned/photographed tab images and Apple Music playback.

---

## Context: Existing Repo

This spec is for the **Viblings iOS app**, being repurposed and renamed to Woodshed. The existing repo has:

- Working MusicKit integration
- SwiftUI foundation
- Likely an existing TestFlight entry

Claude Code should:
1. Audit the existing codebase before building anything new
2. Rename app to "Woodshed" throughout (display name, bundle ID suffix, etc.)
3. Preserve and reuse MusicKit wiring wherever possible
4. Remove Viblings-specific features that don't apply

---

## Platform & Tech Stack

- **Platform:** iOS (iPhone primary, iPad supported)
- **Framework:** SwiftUI
- **Music:** MusicKit (Apple Music playback)
- **Persistence:** iCloud Drive (JSON config files + image assets)
- **No backend required** — entirely client-side
- **Minimum iOS:** 16.0
- **Orientation:** Portrait (iPhone), Portrait + Landscape (iPad)

---

## Core Concept: The Setlist

A **Setlist** is the central data structure. It contains an ordered list of **Sections**.

Each **Section** has:
- `title` — e.g. "Intro", "Verse 1", "Chorus", "Bridge", "Solo", "Outro"
- `songTitle` — the song this section belongs to
- `appleMusicID` — the Apple Music track identifier
- `startTime` — timestamp in seconds (e.g. 32.5)
- `endTime` — timestamp in seconds (e.g. 75.0)
- `instrument` — e.g. "Guitar", "Bass", "Drums", "Keys"
- `role` — e.g. "Lead", "Rhythm", "Fill" (optional, free text)
- `tabImageFilename` — filename of the attached tab/sheet music image stored in iCloud Drive (optional)
- `notes` — free text practice notes (optional)

A **Setlist** has:
- `id` — UUID
- `title` — e.g. "Appetite for Destruction", "Morning Warmup"
- `sections` — ordered array of Section
- `createdAt`, `updatedAt`

---

## Data Persistence (iCloud Drive)

All data lives in the app's iCloud Drive container — no SQLite, no CoreData, no server.

```
iCloud Drive / Woodshed /
├── setlists/
│   ├── appetite-for-destruction.json
│   └── warmup.json
└── tabs/
    ├── wttj-intro.jpg
    ├── wttj-verse1.jpg
    └── ...
```

- Setlists are JSON files — human-readable and hand-editable if needed
- Tab images are JPG/PNG stored in the tabs/ folder, referenced by filename
- iCloud sync is automatic and free
- **Future:** Sharing a setlist = sharing the JSON + referenced tab images via standard iOS share sheet. Design the file structure to support this without building it in v1.

---

## App Structure (Screens)

### 1. Setlist Library (Home)
- List of all setlists
- Tap to open a setlist
- Button to create new setlist
- Simple, clean — this is a utility app not a social feed

### 2. Setlist Detail
- Shows all sections in order, grouped by song
- Each section row shows: song title, section name, instrument/role, duration
- Tap section to edit
- "Play All" button — starts Practice Mode from the beginning
- "Play From Here" — starts Practice Mode from a selected section
- Add/reorder/delete sections

### 3. Practice Mode (Core Experience)
- Full screen during playback
- **Top half:** Tab image for current section (pinch to zoom, scrollable if tall)
- **Bottom half:** Playback controls + section info
- Shows: current song, section name, timestamp progress within section
- Controls: Play/Pause, Previous Section, Next Section, Loop Toggle, Speed Control
- **Loop Toggle:** prominent button in Practice Mode — when active, current section repeats indefinitely instead of advancing. Default to ON when entering a section manually (tapping "Play From Here"). Default to OFF when playing through a full setlist.
- **Speed Control:** 0.5x / 0.75x / 1.0x buttons. Note: MusicKit streaming may not support rate control — Claude Code should investigate AVFoundation local file playback as fallback for downloaded tracks. If not achievable in v1, stub the UI and note the limitation.
- Auto-advances to next section when `endTime` is reached (only when loop is OFF)
- If no tab image: shows song title + section name in large text on a warm background
- No clutter — this is what you stare at while playing guitar

### 4. Section Editor
- Edit all fields for a section
- Timestamp picker: scrub the Apple Music track to find start/end points, tap to set
- Tab image: attach from Photos, Camera, or Files
- Instrument + role fields (free text with suggestions)
- Notes field

### 5. Song Browser (Apple Music)
- Search Apple Music to find a track
- Returns `appleMusicID` and `songTitle` to use in sections
- Reuses existing MusicKit search from Viblings if available

### 6. Settings
- Default instrument (pre-fills new sections)
- Countdown before section starts (0 / 1 / 2 / 3 seconds)
- Tab image display mode (fit / fill / scroll)

---

## Playback Behavior

- MusicKit plays the Apple Music track
- App seeks to `startTime` on section start
- Monitors playback position — when position >= `endTime`, behavior depends on loop mode
- **Loop ON:** seek back to `startTime` of current section, continue playing
- **Loop OFF:** brief pause (0.5s), seek to next section's `startTime`, resume
- **Speed control:** 0.5x / 0.75x / 1.0x buttons always visible in Practice Mode
  - For **local/downloaded tracks**: use AVFoundation rate control — fully supported
  - For **streamed tracks**: buttons visible but disabled; show a gentle informational message (not a paywall): *"Slow playback works with downloaded tracks. Buy on iTunes, or purchase from the artist directly and add to your library."*
  - The app does not care how the track got into the local library — iTunes purchase, Bandcamp purchase imported via Music app, CD rip, etc. AVFoundation just sees a local file.
  - This is an intentional anti-monetization design: the app is free with no IAP. If a user wants slow playback, they buy the music. Money goes to the artist.
- If section has no `endTime`: play until user manually advances
- Does not require Apple Music subscription if all tracks are local — MusicKit used for search/discovery only

---

## Tab Image Handling

- Images stored in iCloud Drive `tabs/` folder
- Displayed in Practice Mode — fit to available space by default
- Pinch to zoom supported
- If image is tall (multi-line tab): scrollable vertically
- User attaches images from: Camera (photograph songbook page), Photos library, Files app
- App copies image to iCloud Drive `tabs/` folder on attach and stores filename reference
- Cropping: user is responsible for cropping to relevant section before attaching — app does not crop

---

## V1 Scope

**In:**
- Setlist create/edit/delete
- Section create/edit/delete/reorder
- Apple Music playback with timestamp seeking
- Tab image attachment and display
- Practice Mode with auto-advance
- iCloud Drive persistence
- Rename from Viblings to Woodshed

**Out (future):**
- Setlist sharing / band mode
- In-app tab cropping
- Audio recording / playback of your own playing
- Metronome
- Tuner
- Watch app
- Android
- Any backend or user accounts

---

## Initial Content: Appetite for Destruction

The developer will seed the app with one setlist covering songs from *Appetite for Destruction*. This involves:

1. Photographing relevant pages of the physical songbook
2. Cropping images per section
3. Finding timestamp ranges in Apple Music for each section
4. Creating the setlist JSON manually or through the app UI

This is a manual bootstrapping process — no import tool needed in v1. The app just needs to make it as painless as possible via the Section Editor.

---

## File Structure (Suggested)

```
Woodshed/
├── App/
│   └── WoodshedApp.swift
├── Views/
│   ├── SetlistLibraryView.swift
│   ├── SetlistDetailView.swift
│   ├── PracticeModeView.swift
│   ├── SectionEditorView.swift
│   ├── SongBrowserView.swift
│   └── SettingsView.swift
├── Models/
│   ├── Setlist.swift
│   └── Section.swift
├── Services/
│   ├── MusicKitService.swift       # reuse/adapt from Viblings
│   ├── iCloudStorageService.swift
│   └── PlaybackCoordinator.swift
└── Tests/
    ├── PlaybackCoordinatorTests.swift
    └── iCloudStorageServiceTests.swift
```

---

## Design Principles

- **Utility first** — this is a tool, not a product. Clean, fast, no onboarding friction.
- **Practice Mode is the hero screen** — everything else exists to set it up
- **No gamification** — no streaks, no points, no badges
- **Warm and simple** — not cold and techy. Comfortable to look at while playing
- **Phone-first, iPad-friendly** — design for iPhone, ensure iPad layout is usable

---

## Success Criteria for V1

- App renamed to Woodshed, running on TestFlight
- Can create a setlist with sections tied to Apple Music tracks and timestamp ranges
- Practice Mode plays sections in sequence, auto-advances, displays tab images
- iCloud Drive persistence works across app restarts
- Appetite for Destruction setlist loaded and usable for daily practice
