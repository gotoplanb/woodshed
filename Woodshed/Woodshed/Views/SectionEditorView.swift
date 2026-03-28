import SwiftUI
import PhotosUI

struct SectionEditorView: View {
    @Environment(StorageService.self) private var storage
    @Environment(MusicKitService.self) private var musicService
    @Environment(\.dismiss) private var dismiss
    let setlistID: UUID
    let songID: UUID
    let sectionID: UUID?

    @State private var title = ""
    @State private var startTime: TimeInterval = 0
    @State private var endTime: TimeInterval? = nil
    @State private var hasEndTime = false
    @State private var role = ""
    @State private var notes = ""
    @State private var tabImageFilename: String?
    @State private var clipTimer: Timer?
    @State private var selectedPhoto: PhotosPickerItem?

    private var isNew: Bool { sectionID == nil }

    private var song: SongEntry? {
        storage.setlists.first { $0.id == setlistID }?.songs.first { $0.id == songID }
    }

    var body: some View {
        Form {
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
                .disabled(title.isEmpty)
            }
        }
        .onAppear { loadExisting() }
        .onDisappear {
            clipTimer?.invalidate()
            musicService.stop()
        }
    }

    private var sectionInfoSection: some View {
        SwiftUI.Section("Section Info") {
            TextField("Section Name (e.g. Intro, Verse 1)", text: $title)
            TextField("Role (optional)", text: $role)
        }
    }

    private var timestampSection: some View {
        SwiftUI.Section("Timestamps") {
            if let song {
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

                LabeledContent("Position") {
                    Text(Section.formatTime(musicService.currentPlaybackTime))
                        .font(.system(.body, design: .monospaced))
                }

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

            HStack {
                Text("Start").foregroundStyle(.secondary)
                Spacer()
                Button { startTime = max(0, startTime - 1) } label: { Image(systemName: "chevron.left") }
                Text(Section.formatTime(startTime))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 50, alignment: .center)
                Button { startTime += 1 } label: { Image(systemName: "chevron.right") }
            }

            HStack {
                Text("End").foregroundStyle(.secondary)
                Spacer()
                if hasEndTime, let end = endTime {
                    Button { endTime = max(startTime + 1, end - 1) } label: { Image(systemName: "chevron.left") }
                    Text(Section.formatTime(end))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 50, alignment: .center)
                    Button { endTime = end + 1 } label: { Image(systemName: "chevron.right") }
                } else {
                    Text("—").foregroundStyle(.secondary)
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

    private var notesSection: some View {
        SwiftUI.Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 60)
        }
    }

    private func playFromStart() async {
        guard let song else { return }
        guard let foundSong = await musicService.lookupSong(byID: song.appleMusicID, title: song.title) else { return }
        await musicService.play(song: foundSong, startTime: startTime)
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

    private func loadExisting() {
        guard let song,
              let sectionID,
              let section = song.sections.first(where: { $0.id == sectionID }) else {
            return
        }
        title = section.title
        startTime = section.startTime
        endTime = section.endTime
        hasEndTime = section.endTime != nil
        role = section.role ?? ""
        notes = section.notes ?? ""
        tabImageFilename = section.tabImageFilename
    }

    private func saveSection() {
        guard var setlist = storage.setlists.first(where: { $0.id == setlistID }),
              let songIndex = setlist.songs.firstIndex(where: { $0.id == songID }) else { return }

        let section = Section(
            id: sectionID ?? UUID(),
            title: title,
            startTime: startTime,
            endTime: hasEndTime ? endTime : nil,
            role: role.isEmpty ? nil : role,
            tabImageFilename: tabImageFilename,
            notes: notes.isEmpty ? nil : notes
        )

        if let index = setlist.songs[songIndex].sections.firstIndex(where: { $0.id == section.id }) {
            setlist.songs[songIndex].sections[index] = section
        } else {
            setlist.songs[songIndex].sections.append(section)
        }

        storage.save(setlist)
    }
}
