import AVFoundation
import Foundation
import MusicKit
import Observation

enum PlaybackMode {
    case jam       // Whole songs, no section awareness
    case practice  // Section-aware with loop and timestamps
}

enum ActiveEngine {
    case musicKit
    case avPlayer(AVAudioPlayer)
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
    private var isLoopSeeking = false
    private var activeEngine: ActiveEngine = .musicKit

    // MARK: - Computed Properties

    var currentJamSong: SongEntry? {
        guard mode == .jam, songs.indices.contains(currentSongIndex) else { return nil }
        return songs[currentSongIndex]
    }

    var currentSection: Section? {
        guard mode == .practice, let song = currentSong else { return nil }
        guard song.sections.indices.contains(currentSectionIndex) else { return nil }
        return song.sections[currentSectionIndex]
    }

    var songProgress: Double { 0 }

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
        await playSong(song, startTime: 0)
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
        await playSong(song, startTime: 0)
    }

    func seekToSection(_ index: Int) {
        guard mode == .practice, let song = currentSong else { return }
        guard song.sections.indices.contains(index) else { return }
        currentSectionIndex = index
        let section = song.sections[index]
        seek(to: section.startTime)
    }

    // MARK: - Unified Playback

    private func playSong(_ song: SongEntry, startTime: TimeInterval) async {
        stopCurrentEngine()

        // Try local playback first (for speed control)
        if let player = findLocalTrack(appleMusicID: song.appleMusicID) {
            activeEngine = .avPlayer(player)
            rateControlAvailable = true
            player.enableRate = true
            player.rate = playbackRate
            player.currentTime = startTime
            player.play()
            isPlaying = true
            playbackError = nil
            startMonitoring()
            return
        }

        // Fall back to MusicKit streaming
        let found = await musicService.lookupSong(byID: song.appleMusicID, title: song.title)
        guard let found else {
            playbackError = "Song not found in Apple Music"
            return
        }

        activeEngine = .musicKit
        rateControlAvailable = false

        await musicService.play(song: found, startTime: startTime)
        if let error = musicService.lastError {
            playbackError = error
        } else {
            isPlaying = true
            playbackError = nil
            startMonitoring()
        }
    }

    // MARK: - Shared Controls

    func pause() {
        switch activeEngine {
        case .avPlayer(let player):
            player.pause()
        case .musicKit:
            musicService.pause()
        }
        isPlaying = false
    }

    func resume() async {
        switch activeEngine {
        case .avPlayer(let player):
            player.rate = playbackRate
            player.play()
            isPlaying = true
        case .musicKit:
            await musicService.resume()
            isPlaying = true
        }
    }

    func togglePlayPause() async {
        if isPlaying { pause() } else { await resume() }
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if case .avPlayer(let player) = activeEngine, player.isPlaying {
            player.rate = rate
        }
    }

    func endSession() {
        stopCurrentEngine()
        isPlaying = false
        isSessionActive = false
        isCountingDown = false
        countdownRemaining = 0
        songs = []
        currentSong = nil
        currentSongIndex = 0
        currentSectionIndex = 0
        playbackError = nil
        rateControlAvailable = false
        activeEngine = .musicKit
        stopMonitoring()
    }

    private func stopCurrentEngine() {
        switch activeEngine {
        case .avPlayer(let player):
            player.stop()
        case .musicKit:
            musicService.stop()
        }
    }

    private func seek(to time: TimeInterval) {
        switch activeEngine {
        case .avPlayer(let player):
            player.currentTime = time
        case .musicKit:
            // Pause + set time + play for MusicKit (direct seek unreliable on streaming)
            let shared = ApplicationMusicPlayer.shared
            shared.pause()
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                shared.playbackTime = time
                try? await shared.play()
            }
        }
    }

    // MARK: - Local Track Detection
    //
    // MPMediaLibrary/MPMediaQuery crash on iOS 26 beta, so local track detection
    // via the MediaPlayer framework is disabled. Speed control requires AVFoundation
    // with a local file URL, which only MPMediaQuery can provide.
    //
    // When Apple fixes MPMediaLibrary in a future iOS 26 release, re-enable by:
    // 1. import MediaPlayer
    // 2. Use MPMediaPropertyPredicate with MPMediaItemPropertyPlaybackStoreID
    // 3. Get item.assetURL and create AVAudioPlayer
    //
    // For now, all playback goes through MusicKit (streaming, no speed control).

    private func findLocalTrack(appleMusicID: String) -> AVAudioPlayer? {
        // Disabled: MPMediaLibrary crashes on iOS 26.4 beta
        return nil
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
                    self.updatePlaybackTime()
                    await self.checkBoundaries()
                }
            }
        }
    }

    private func updatePlaybackTime() {
        switch activeEngine {
        case .avPlayer(let player):
            currentPlaybackTime = player.currentTime
        case .musicKit:
            currentPlaybackTime = ApplicationMusicPlayer.shared.playbackTime
        }
    }

    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func checkBoundaries() async {
        switch mode {
        case .jam: await checkJamSongEnd()
        case .practice: await checkSectionBoundary()
        }
    }

    private func checkJamSongEnd() async {
        guard isPlaying else { return }
        let status = ApplicationMusicPlayer.shared.state.playbackStatus
        // If the player is no longer playing, the song ended
        if status == .paused || status == .stopped || status == .interrupted {
            // Small delay to avoid false triggers during seeks
            try? await Task.sleep(for: .milliseconds(500))
            let recheckStatus = ApplicationMusicPlayer.shared.state.playbackStatus
            if recheckStatus == .paused || recheckStatus == .stopped || recheckStatus == .interrupted {
                await nextSong()
            }
        }
    }

    private func checkSectionBoundary() async {
        guard isPlaying, let song = currentSong else { return }

        // Check loop boundary BEFORE updating section index
        if let section = currentSection, let endTime = section.endTime,
           currentPlaybackTime >= endTime, isLooping, !isLoopSeeking {
            isLoopSeeking = true
            switch activeEngine {
            case .avPlayer(let player):
                player.currentTime = section.startTime
                isLoopSeeking = false
            case .musicKit:
                let player = ApplicationMusicPlayer.shared
                player.pause()
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    player.playbackTime = section.startTime
                    try? await player.play()
                    await MainActor.run { self.isLoopSeeking = false }
                }
            }
            return
        }

        // Update current section index based on playback position
        if let newIndex = song.sections.lastIndex(where: { currentPlaybackTime >= $0.startTime }),
           newIndex != currentSectionIndex {
            currentSectionIndex = newIndex
        }
    }
}
