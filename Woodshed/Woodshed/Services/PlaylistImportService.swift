import Foundation
import MusicKit
import Observation

@Observable
final class PlaylistImportService {
    var playlists: [Playlist] = []
    var isLoading = false

    func loadPlaylists() async {
        isLoading = true
        do {
            var request = MusicLibraryRequest<Playlist>()
            request.sort(by: \.name, ascending: true)
            let response = try await request.response()
            await MainActor.run {
                playlists = Array(response.items)
                isLoading = false
            }
        } catch {
            print("Failed to load playlists: \(error)")
            await MainActor.run {
                playlists = []
                isLoading = false
            }
        }
    }

    func importPlaylist(_ playlist: Playlist) async -> Setlist? {
        do {
            // Load the playlist with its tracks
            let detailed = try await playlist.with(.tracks)
            guard let tracks = detailed.tracks else { return nil }

            var songs: [SongEntry] = []
            for track in tracks {
                // Each track becomes a SongEntry with placeholder sections
                let song = SongEntry(
                    title: track.title,
                    appleMusicID: track.id.rawValue,
                    instrument: "Guitar",
                    sections: defaultSections()
                )
                songs.append(song)
            }

            return Setlist(
                title: playlist.name,
                songs: songs
            )
        } catch {
            print("Failed to import playlist: \(error)")
            return nil
        }
    }

    private func defaultSections() -> [Section] {
        [
            Section(title: "Intro", startTime: 0, endTime: 10),
            Section(title: "Verse", startTime: 10, endTime: 40),
            Section(title: "Chorus", startTime: 40, endTime: 60),
        ]
    }
}
