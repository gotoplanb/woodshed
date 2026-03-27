import SwiftUI
import MusicKit

struct SongBrowserView: View {
    @Environment(MusicKitService.self) private var musicService
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    let onSelect: (String, String) -> Void

    var body: some View {
        NavigationStack {
            List(musicService.searchResults, id: \.id) { song in
                Button {
                    onSelect(song.id.rawValue, song.title)
                    dismiss()
                } label: {
                    HStack {
                        if let artwork = song.artwork {
                            ArtworkImage(artwork, width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        VStack(alignment: .leading) {
                            Text(song.title)
                            Text(song.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let duration = song.duration {
                            Text(Section.formatTime(duration))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .searchable(text: $searchQuery, prompt: "Search Apple Music")
            .onChange(of: searchQuery) { _, newValue in
                Task {
                    await musicService.searchTracks(query: newValue)
                }
            }
            .navigationTitle("Find Song")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if musicService.searchResults.isEmpty && !searchQuery.isEmpty && !musicService.isSearching {
                    ContentUnavailableView.search(text: searchQuery)
                }
            }
        }
    }
}
