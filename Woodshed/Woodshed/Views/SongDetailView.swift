import SwiftUI

struct SongDetailView: View {
    @Environment(StorageService.self) private var storage
    @Environment(PlaybackCoordinator.self) private var coordinator
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let setlistID: UUID
    let songID: UUID
    @State private var showingTab = false

    private var song: SongEntry? {
        storage.setlists.first { $0.id == setlistID }?.songs.first { $0.id == songID }
    }

    /// Tab image filename for the current section, if any
    private var currentTabImage: String? {
        coordinator.currentSection?.tabImageFilename
    }

    var body: some View {
        Group {
            if let song {
                if horizontalSizeClass == .regular, currentTabImage != nil {
                    // iPad landscape with tab image: side-by-side
                    wideContent(song)
                } else {
                    // iPhone, iPad portrait, or no tab image: compact
                    compactContent(song)
                }
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

    // MARK: - Wide Layout (iPad landscape with tabs)

    private func wideContent(_ song: SongEntry) -> some View {
        HStack(spacing: 0) {
            // Left: playback controls + section list
            VStack(spacing: 0) {
                playbackControls(song)
                Divider()
                if song.sections.isEmpty {
                    ContentUnavailableView("No Sections", systemImage: "music.note")
                } else {
                    sectionList(song)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Right: tab image
            if let tabFilename = currentTabImage {
                TabImageView(filename: tabFilename)
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(song.title)
        .task {
            guard !coordinator.isSessionActive else { return }
            await coordinator.startPracticeSession(song: song)
        }
    }

    // MARK: - Compact Layout (iPhone / iPad portrait / no tabs)

    private func compactContent(_ song: SongEntry) -> some View {
        VStack(spacing: 0) {
            playbackControls(song)
            Divider()
            if song.sections.isEmpty {
                ContentUnavailableView("No Sections", systemImage: "music.note", description: Text("Edit the setlist JSON to add sections."))
            } else {
                sectionList(song)
            }
        }
        .navigationTitle(song.title)
        .toolbar {
            if currentTabImage != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingTab.toggle()
                    } label: {
                        Image(systemName: "doc.richtext")
                    }
                }
            }
        }
        .sheet(isPresented: $showingTab) {
            if let tabFilename = currentTabImage {
                NavigationStack {
                    TabImageView(filename: tabFilename)
                        .navigationTitle(coordinator.currentSection?.title ?? "Tab")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingTab = false }
                            }
                        }
                }
            }
        }
        .task {
            guard !coordinator.isSessionActive else { return }
            await coordinator.startPracticeSession(song: song)
        }
    }

    // MARK: - Playback Controls

    private func playbackControls(_ song: SongEntry) -> some View {
        VStack(spacing: 12) {
            Text(Section.formatTime(coordinator.currentPlaybackTime))
                .font(.system(.title2, design: .monospaced))

            ProgressView(value: coordinator.songProgress)
                .padding(.horizontal)

            HStack(spacing: 40) {
                Button { Task { await coordinator.togglePlayPause() } } label: {
                    Image(systemName: coordinator.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }

                Button {
                    coordinator.toggleLoop()
                } label: {
                    Image(systemName: coordinator.isLooping ? "repeat.1" : "repeat")
                        .font(.title2)
                        .foregroundStyle(coordinator.isLooping ? .primary : .secondary)
                }
            }

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

    // MARK: - Section List

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
