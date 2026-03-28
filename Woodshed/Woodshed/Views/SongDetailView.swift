import SwiftUI

struct SongDetailView: View {
    @Environment(StorageService.self) private var storage
    @Environment(PlaybackCoordinator.self) private var coordinator
    let setlistID: UUID
    let songID: UUID

    private var song: SongEntry? {
        storage.setlists.first { $0.id == setlistID }?.songs.first { $0.id == songID }
    }

    var body: some View {
        Group {
            if let song {
                content(song)
            } else {
                ContentUnavailableView("Song Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .onDisappear {
            if coordinator.isSessionActive {
                coordinator.endSession()
            }
        }
    }

    private func content(_ song: SongEntry) -> some View {
        VStack(spacing: 0) {
            // Playback controls
            playbackControls(song)

            Divider()

            // Section list
            if song.sections.isEmpty {
                ContentUnavailableView("No Sections", systemImage: "music.note", description: Text("Tap + to add sections for practice mode."))
            } else {
                sectionList(song)
            }
        }
        .navigationTitle(song.title)
        .task {
            guard !coordinator.isSessionActive else { return }
            await coordinator.startPracticeSession(song: song)
        }
    }

    private func playbackControls(_ song: SongEntry) -> some View {
        VStack(spacing: 12) {
            // Position display
            Text(Section.formatTime(coordinator.currentPlaybackTime))
                .font(.system(.title2, design: .monospaced))

            // Progress bar
            ProgressView(value: coordinator.songProgress)
                .padding(.horizontal)

            // Transport
            HStack(spacing: 40) {
                Button { Task { await coordinator.togglePlayPause() } } label: {
                    Image(systemName: coordinator.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }

                // Loop toggle
                Button {
                    coordinator.toggleLoop()
                } label: {
                    Image(systemName: coordinator.isLooping ? "repeat.1" : "repeat")
                        .font(.title2)
                        .foregroundStyle(coordinator.isLooping ? .primary : .secondary)
                }
            }

            // Speed control
            HStack {
                Picker("Speed", selection: Binding(
                    get: { coordinator.playbackRate },
                    set: { coordinator.setRate($0) }
                )) {
                    Text("0.5x").tag(Float(0.5))
                    Text("0.75x").tag(Float(0.75))
                    Text("1.0x").tag(Float(1.0))
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(!coordinator.rateControlAvailable)
            }

            if !coordinator.rateControlAvailable {
                Text("Slow playback works with downloaded tracks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = coordinator.playbackError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

        }
        .padding()
    }

    private func sectionList(_ song: SongEntry) -> some View {
        List {
            ForEach(Array(song.sections.enumerated()), id: \.element.id) { index, section in
                Button {
                    coordinator.seekToSection(index)
                } label: {
                    sectionRow(section, isActive: coordinator.currentSectionIndex == index && coordinator.isSessionActive)
                }
                .tint(.primary)
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deleteSection(at: index)
                    }
                }
                .listRowBackground(
                    coordinator.currentSectionIndex == index && coordinator.isSessionActive
                        ? Color.blue.opacity(0.1)
                        : nil
                )
            }
            .onMove(perform: moveSections)
        }
    }

    private func sectionRow(_ section: Section, isActive: Bool) -> some View {
        HStack {
            if isActive {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.tint)
                    .font(.caption)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .fontWeight(isActive ? .semibold : .regular)
                HStack {
                    Text(section.formattedTimeRange)
                        .font(.caption.monospaced())
                    if let role = section.role {
                        Text("· \(role)")
                            .font(.caption)
                    }
                    if section.tabImageFilename != nil {
                        Image(systemName: "doc.richtext")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func deleteSection(at index: Int) {
        guard var setlist = storage.setlists.first(where: { $0.id == setlistID }),
              let songIndex = setlist.songs.firstIndex(where: { $0.id == songID }) else { return }
        setlist.songs[songIndex].sections.remove(at: index)
        storage.save(setlist)
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        guard var setlist = storage.setlists.first(where: { $0.id == setlistID }),
              let songIndex = setlist.songs.firstIndex(where: { $0.id == songID }) else { return }
        setlist.songs[songIndex].sections.move(fromOffsets: source, toOffset: destination)
        storage.save(setlist)
    }
}
