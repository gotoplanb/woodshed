import SwiftUI
import PhotosUI

struct SectionEditorView: View {
    @Environment(StorageService.self) private var storage
    @Environment(MusicKitService.self) private var musicService
    @Environment(\.dismiss) private var dismiss
    let setlistID: UUID
    let sectionID: UUID?

    @State private var title = ""
    @State private var songTitle = ""
    @State private var appleMusicID = ""
    @State private var startTime: TimeInterval = 0
    @State private var endTime: TimeInterval? = nil
    @State private var hasEndTime = false
    @State private var instrument = "Guitar"
    @State private var role = ""
    @State private var notes = ""
    @State private var tabImageFilename: String?
    @State private var showingSongBrowser = false
    @State private var clipTimer: Timer?
    @State private var selectedPhoto: PhotosPickerItem?

    private var isNew: Bool { sectionID == nil }

    var body: some View {
        Form {
            songSection
            sectionInfoSection
            timestampSection
            tabImageSection
            notesSection
        }
        .navigationTitle(isNew ? "New Section" : "Edit Section")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveSection()
                    dismiss()
                }
                .disabled(title.isEmpty || appleMusicID.isEmpty)
            }
        }
        .sheet(isPresented: $showingSongBrowser) {
            SongBrowserView { id, name in
                appleMusicID = id
                songTitle = name
            }
        }
        .onAppear { loadExisting() }
        .onDisappear {
            clipTimer?.invalidate()
            musicService.stop()
        }
    }

    // MARK: - Song Selection

    private var songSection: some View {
        SwiftUI.Section("Song") {
            if appleMusicID.isEmpty {
                Button("Search Apple Music") {
                    showingSongBrowser = true
                }
            } else {
                LabeledContent("Song", value: songTitle)
                Button("Change Song") {
                    showingSongBrowser = true
                }
            }
        }
    }

    // MARK: - Section Info

    private var sectionInfoSection: some View {
        SwiftUI.Section("Section Info") {
            TextField("Section Name (e.g. Intro, Verse 1)", text: $title)
            TextField("Instrument", text: $instrument)
            TextField("Role (optional)", text: $role)
        }
    }

    // MARK: - Timestamp Picker

    private var timestampSection: some View {
        SwiftUI.Section("Timestamps") {
            // Playback controls
            if !appleMusicID.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        if musicService.isPlaying {
                            clipTimer?.invalidate()
                            musicService.pause()
                        } else {
                            Task { await playFromStart() }
                        }
                    } label: {
                        Image(systemName: musicService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)

                // Current position
                LabeledContent("Position") {
                    Text(Section.formatTime(musicService.currentPlaybackTime))
                        .font(.system(.body, design: .monospaced))
                }

                // Mark buttons
                HStack {
                    Button("Mark Start") {
                        startTime = musicService.currentPlaybackTime
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Mark End") {
                        endTime = musicService.currentPlaybackTime
                        hasEndTime = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Time display with steppers
            HStack {
                Text("Start")
                    .foregroundStyle(.secondary)
                Spacer()
                Button { startTime = max(0, startTime - 1) } label: {
                    Image(systemName: "chevron.left")
                }
                Text(Section.formatTime(startTime))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 50, alignment: .center)
                Button { startTime += 1 } label: {
                    Image(systemName: "chevron.right")
                }
            }

            HStack {
                Text("End")
                    .foregroundStyle(.secondary)
                Spacer()
                if hasEndTime, let end = endTime {
                    Button { endTime = max(startTime + 1, end - 1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    Text(Section.formatTime(end))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 50, alignment: .center)
                    Button { endTime = end + 1 } label: {
                        Image(systemName: "chevron.right")
                    }
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Has End Time", isOn: $hasEndTime)
                .onChange(of: hasEndTime) { _, newValue in
                    if newValue && endTime == nil {
                        endTime = startTime + 30
                    } else if !newValue {
                        endTime = nil
                    }
                }

            if hasEndTime, let end = endTime {
                LabeledContent("Duration") {
                    Text(Section.formatTime(end - startTime))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Tab Image

    private var tabImageSection: some View {
        SwiftUI.Section("Tab Image") {
            if let filename = tabImageFilename,
               let url = storage.tabImageURL(for: filename),
               let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)

                Button("Remove Image", role: .destructive) {
                    tabImageFilename = nil
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(tabImageFilename == nil ? "Attach Tab Image" : "Replace Image", systemImage: "photo")
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    guard let newItem else { return }
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let filename = "\(UUID().uuidString).jpg"
                        storage.saveTabImage(data, filename: filename)
                        tabImageFilename = filename
                    }
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        SwiftUI.Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 60)
        }
    }

    // MARK: - Playback

    private func playFromStart() async {
        guard let song = await musicService.lookupSong(byID: appleMusicID) else { return }
        await musicService.play(song: song, startTime: startTime)
        clipTimer?.invalidate()
        if hasEndTime, let end = endTime {
            clipTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                if musicService.currentPlaybackTime >= end {
                    clipTimer?.invalidate()
                    musicService.pause()
                }
            }
        }
    }

    // MARK: - Load / Save

    private func loadExisting() {
        instrument = storage.settings.defaultInstrument

        guard let sectionID,
              let setlist = storage.setlists.first(where: { $0.id == setlistID }),
              let section = setlist.sections.first(where: { $0.id == sectionID }) else {
            return
        }
        title = section.title
        songTitle = section.songTitle
        appleMusicID = section.appleMusicID
        startTime = section.startTime
        endTime = section.endTime
        hasEndTime = section.endTime != nil
        instrument = section.instrument
        role = section.role ?? ""
        notes = section.notes ?? ""
        tabImageFilename = section.tabImageFilename
    }

    private func saveSection() {
        guard var setlist = storage.setlists.first(where: { $0.id == setlistID }) else { return }

        let section = Section(
            id: sectionID ?? UUID(),
            title: title,
            songTitle: songTitle,
            appleMusicID: appleMusicID,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            instrument: instrument,
            role: role.isEmpty ? nil : role,
            tabImageFilename: tabImageFilename,
            notes: notes.isEmpty ? nil : notes
        )

        if let index = setlist.sections.firstIndex(where: { $0.id == section.id }) {
            setlist.sections[index] = section
        } else {
            setlist.sections.append(section)
        }

        storage.save(setlist)
    }
}
