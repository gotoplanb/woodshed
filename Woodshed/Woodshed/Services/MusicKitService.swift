import Foundation
import MusicKit
import Observation

protocol MusicPlayerProtocol {
    var playbackTime: TimeInterval { get set }
    var queue: ApplicationMusicPlayer.Queue { get set }
    func play() async throws
    func pause()
    func stop()
}

extension ApplicationMusicPlayer: MusicPlayerProtocol {}

@Observable
final class MusicKitService {
    var authorizationStatus: MusicAuthorization.Status = .notDetermined
    var searchResults: [Song] = []
    var isSearching = false
    var isPlaying = false
    var currentPlaybackTime: TimeInterval = 0

    private var player: any MusicPlayerProtocol
    private var positionTimer: Timer?

    init(player: any MusicPlayerProtocol = ApplicationMusicPlayer.shared) {
        self.player = player
    }

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.authorizationStatus = status
        }
    }

    func searchTracks(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run { searchResults = [] }
            return
        }

        await MainActor.run { isSearching = true }

        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 20
            let response = try await request.response()
            await MainActor.run {
                searchResults = Array(response.songs)
                isSearching = false
            }
        } catch {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
        }
    }

    func lookupSong(byID id: String, title: String? = nil, artist: String? = nil) async -> Song? {
        // Library IDs (starting with "i.") don't reliably resolve to the correct
        // catalog entry — skip straight to title+artist search for these
        if !id.hasPrefix("i.") {
            let musicItemID = MusicItemID(id)
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemID)
            if let song = try? await request.response().items.first {
                return song
            }
        }

        // Search by title + artist for disambiguation
        guard let title else { return nil }
        let searchTerm: String
        if let artist, !artist.isEmpty {
            searchTerm = "\(title) \(artist)"
        } else {
            searchTerm = title
        }
        var searchRequest = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        searchRequest.limit = 10
        if let results = try? await searchRequest.response() {
            // Prefer exact artist match
            if let artist, !artist.isEmpty {
                if let match = results.songs.first(where: { $0.artistName.localizedCaseInsensitiveContains(artist) }) {
                    return match
                }
            }
            return results.songs.first
        }
        return nil
    }

    var lastError: String?

    func play(song: Song, startTime: TimeInterval = 0) async {
        do {
            player.queue = [song]
            try await player.play()
            player.playbackTime = startTime
            await MainActor.run {
                isPlaying = true
                lastError = nil
                startPositionMonitoring()
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isPlaying = false
            }
            print("Playback error: \(error)")
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() async {
        do {
            try await player.play()
            isPlaying = true
            startPositionMonitoring()
        } catch {
            print("Resume error: \(error)")
        }
    }

    func seek(to time: TimeInterval) {
        player.playbackTime = time
    }

    func stop() {
        player.stop()
        isPlaying = false
        stopPositionMonitoring()
    }

    private func startPositionMonitoring() {
        stopPositionMonitoring()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.currentPlaybackTime = ApplicationMusicPlayer.shared.playbackTime
            }
        }
    }

    private func stopPositionMonitoring() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
}
