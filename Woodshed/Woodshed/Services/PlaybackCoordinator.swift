import AVFoundation
import Foundation
import MediaPlayer
import MusicKit
import Observation

enum PlaybackMode {
    case jam       // Whole songs, no section awareness
    case practice  // Section-aware with loop and timestamps
}

@Observable
final class PlaybackCoordinator {
    // Shared state
    var isPlaying: Bool = false
    var currentPlaybackTime: TimeInterval = 0
    var isSessionActive: Bool = false
    var playbackError: String?

    // Jam mode state
    var songs: [SongEntry] = []
    var currentSongIndex: Int = 0

    // Practice mode state
    var currentSong: SongEntry?
    var currentSectionIndex: Int = 0
    var isLooping: Bool = false
    var playbackRate: Float = 1.0
    var rateControlAvailable: Bool = false

    // Countdown
    var countdownSeconds: Int = 0
    var countdownRemaining: Int = 0
    var isCountingDown: Bool = false

    var mode: PlaybackMode = .jam
    private let musicService: MusicKitService
    private var monitorTimer: Timer?

    // MARK: - Computed Properties

    /// Current song in Jam Mode
    var currentJamSong: SongEntry? {
        guard mode == .jam, songs.indices.contains(currentSongIndex) else { return nil }
        return songs[currentSongIndex]
    }

    /// Current section in Practice Mode
    var currentSection: Section? {
        guard mode == .practice, let song = currentSong else { return nil }
        guard song.sections.indices.contains(currentSectionIndex) else { return nil }
        return song.sections[currentSectionIndex]
    }

    /// Progress through the current song (0-1), used in both modes
    var songProgress: Double {
        // MusicKit doesn't give us duration easily, so just show time
        // For a rough progress, use playbackTime / estimated duration
        // This is approximate — we could get duration from the Song metadata
        0
    }

    init(musicService: MusicKitService) {
        self.musicService = musicService
    }

    // MARK: - Jam Mode

    func startJamSession(songs: [SongEntry], startIndex: Int) async {
        self.mode = .jam
        self.songs = songs
        self.currentSongIndex = startIndex
        self.isSessionActive = true
        self.isLooping = false
        await playCurrentSongForJam()
    }

    private func playCurrentSongForJam() async {
        guard let song = currentJamSong else { return }

        configureAudioSession()

        let found = await musicService.lookupSong(byID: song.appleMusicID, title: song.title)
        guard let found else {
            playbackError = "Song not found in Apple Music"
            return
        }

        await musicService.play(song: found, startTime: 0)
        if let error = musicService.lastError {
            playbackError = error
        } else {
            isPlaying = true
            playbackError = nil
            startMonitoring()
        }
    }

    func nextSong() async {
        guard mode == .jam else { return }
        guard currentSongIndex < songs.count - 1 else {
            endSession()
            return
        }
        currentSongIndex += 1
        await playCurrentSongForJam()
    }

    func previousSong() async {
        guard mode == .jam else { return }
        guard currentSongIndex > 0 else { return }
        currentSongIndex -= 1
        await playCurrentSongForJam()
    }

    // MARK: - Practice Mode

    func startPracticeSession(song: SongEntry) async {
        self.mode = .practice
        self.currentSong = song
        self.currentSectionIndex = 0
        self.isSessionActive = true
        self.isLooping = false
        self.playbackRate = 1.0

        configureAudioSession()

        let found = await musicService.lookupSong(byID: song.appleMusicID, title: song.title)
        guard let found else {
            playbackError = "Song not found in Apple Music"
            return
        }

        // TODO: detect local vs streaming for rate control
        rateControlAvailable = false

        await musicService.play(song: found, startTime: 0)
        if let error = musicService.lastError {
            playbackError = error
        } else {
            isPlaying = true
            playbackError = nil
            startMonitoring()
        }
    }

    func seekToSection(_ index: Int) {
        guard mode == .practice, let song = currentSong else { return }
        guard song.sections.indices.contains(index) else { return }
        currentSectionIndex = index
        let section = song.sections[index]
        musicService.seek(to: section.startTime)
    }

    // MARK: - Shared Controls

    func pause() {
        musicService.pause()
        isPlaying = false
    }

    func resume() async {
        await musicService.resume()
        isPlaying = true
    }

    func togglePlayPause() async {
        if isPlaying {
            pause()
        } else {
            await resume()
        }
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        // TODO: apply to AVAudioPlayer when local playback is enabled
    }

    func endSession() {
        musicService.stop()
        isPlaying = false
        isSessionActive = false
        isCountingDown = false
        countdownRemaining = 0
        songs = []
        currentSong = nil
        currentSongIndex = 0
        currentSectionIndex = 0
        playbackError = nil
        stopMonitoring()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Position Monitoring

    private func startMonitoring() {
        stopMonitoring()
        DispatchQueue.main.async { [weak self] in
            self?.monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.currentPlaybackTime = ApplicationMusicPlayer.shared.playbackTime
                    await self.checkBoundaries()
                }
            }
        }
    }

    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func checkBoundaries() async {
        switch mode {
        case .jam:
            // In Jam Mode, we don't check boundaries — MusicKit handles end-of-song
            // The player state will change when the song ends naturally
            break
        case .practice:
            await checkSectionBoundary()
        }
    }

    private func checkSectionBoundary() async {
        guard isPlaying, let song = currentSong else { return }

        // Update current section index based on playback position
        if let newIndex = song.sections.lastIndex(where: { currentPlaybackTime >= $0.startTime }) {
            if newIndex != currentSectionIndex {
                currentSectionIndex = newIndex
            }
        }

        // Check if we've reached the end of the current section
        guard let section = currentSection, let endTime = section.endTime else { return }
        guard currentPlaybackTime >= endTime else { return }

        if isLooping {
            musicService.seek(to: section.startTime)
        }
        // If not looping, just let the song keep playing — it'll naturally advance
        // to the next section based on the timestamp check above
    }
}
