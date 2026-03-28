import SwiftUI

struct SetlistDetailView: View {
    @Environment(StorageService.self) private var storage
    let setlistID: UUID
    @State private var showJamMode = false
    @State private var jamStartIndex = 0

    private var setlist: Setlist? {
        storage.setlists.first { $0.id == setlistID }
    }

    var body: some View {
        Group {
            if let setlist {
                content(setlist)
            } else {
                ContentUnavailableView("Setlist Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationDestination(isPresented: $showJamMode) {
            if let setlist {
                JamModeView(setlistID: setlistID, startIndex: jamStartIndex)
            }
        }
    }

    private func content(_ setlist: Setlist) -> some View {
        List {
            ForEach(Array(setlist.songs.enumerated()), id: \.element.id) { index, song in
                NavigationLink(destination: SongDetailView(setlistID: setlistID, songID: song.id)) {
                    songRow(song)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deleteSong(at: index)
                    }
                }
            }
            .onMove(perform: moveSongs)
        }
        .navigationTitle(setlist.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                if !setlist.songs.isEmpty {
                    Button {
                        jamStartIndex = 0
                        showJamMode = true
                    } label: {
                        Label("Jam", systemImage: "play.fill")
                    }
                }
            }
        }
        .overlay {
            if setlist.songs.isEmpty {
                ContentUnavailableView("No Songs", systemImage: "music.note", description: Text("Tap + to add a song."))
            }
        }
    }

    private func songRow(_ song: SongEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song.title)
            HStack {
                Text(song.instrument)
                    .foregroundStyle(.secondary)
                Spacer()
                if song.sections.isEmpty {
                    Text("No sections")
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(song.sections.count) sections")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }

    private func deleteSong(at index: Int) {
        guard var setlist = setlist else { return }
        setlist.songs.remove(at: index)
        storage.save(setlist)
    }

    private func moveSongs(from source: IndexSet, to destination: Int) {
        guard var setlist = setlist else { return }
        setlist.songs.move(fromOffsets: source, toOffset: destination)
        storage.save(setlist)
    }
}
