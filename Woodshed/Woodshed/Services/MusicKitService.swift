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

    var lookupDebug: String = ""

    func lookupSong(byID id: String, title: String? = nil) async -> Song? {
        // Try direct ID lookup first
        do {
            let musicItemID = MusicItemID(id)
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: musicItemID)
            let response = try await request.response()
            if let song = response.items.first {
                lookupDebug = "ID lookup OK: \(song.title)"
                return song
            }
            lookupDebug = "ID lookup: no results"
        } catch {
            lookupDebug = "ID lookup error: \(error)"
        }

        // Fall back to search by title
        guard let title else { return nil }
        do {
            var searchRequest = MusicCatalogSearchRequest(term: title, types: [Song.self])
            searchRequest.limit = 5
            let response = try await searchRequest.response()
            if let song = response.songs.first {
                lookupDebug += " | Search OK: \(song.title)"
                return song
            }
            lookupDebug += " | Search: no results for '\(title)'"
        } catch {
            lookupDebug += " | Search error: \(error)"
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
                self.currentPlaybackTime = self.player.playbackTime
            }
        }
    }

    private func stopPositionMonitoring() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
}
