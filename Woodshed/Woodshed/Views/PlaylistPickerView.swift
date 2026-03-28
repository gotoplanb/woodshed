import SwiftUI
import MusicKit

struct PlaylistPickerView: View {
    @Environment(StorageService.self) private var storage
    @Environment(\.dismiss) private var dismiss
    @State private var importService = PlaylistImportService()
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Group {
                if importService.isLoading {
                    ProgressView("Loading playlists...")
                } else if importService.playlists.isEmpty {
                    ContentUnavailableView("No Playlists", systemImage: "music.note.list", description: Text("Create a playlist in Apple Music first."))
                } else {
                    List(importService.playlists, id: \.id) { playlist in
                        Button {
                            Task {
                                isImporting = true
                                if let setlist = await importService.importPlaylist(playlist) {
                                    storage.save(setlist)
                                    dismiss()
                                }
                                isImporting = false
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(playlist.name)
                                }
                                Spacer()
                                if isImporting {
                                    ProgressView()
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Import Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await importService.loadPlaylists()
            }
        }
    }
}
