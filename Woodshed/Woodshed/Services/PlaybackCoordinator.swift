import AVFoundation
import Foundation
import MediaPlayer
import MusicKit
import Observation

enum PlaybackEngine {
    case musicKit(Song)
    case avFoundation(AVAudioPlayer)
}

@Observable
final class PlaybackCoordinator {
    var currentSectionIndex: Int = 0
    var isPlaying: Bool = false
    var isLooping: Bool = false
    var playbackRate: Float = 1.0
    var currentPlaybackTime: TimeInterval = 0
    var rateControlAvailable: Bool = false
    var countdownRemaining: Int = 0
    var isCountingDown: Bool = false

    var sections: [Section] = []
    var isSessionActive: Bool = false
    var countdownSeconds: Int = 0
    var playbackError: String?
    var debugStatus: String = ""

    private let musicService: MusicKitService
    private var monitorTimer: Timer?
    private var currentEngine: PlaybackEngine?
    private var avPlayer: AVAudioPlayer?

    var currentSection: Section? {
        guard sections.indices.contains(currentSectionIndex) else { return nil }
        return sections[currentSectionIndex]
    }

    var sectionProgress: Double {
        guard let section = currentSection else { return 0 }
        guard let duration = section.duration, duration > 0 else { return 0 }
        let elapsed = currentPlaybackTime - section.startTime
        return min(max(elapsed / duration, 0), 1)
    }

    init(musicService: MusicKitService) {
        self.musicService = musicService
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    func startSession(sections: [Section], startIndex: Int, loopDefault: Bool) async {
        self.sections = sections
        self.currentSectionIndex = startIndex
        self.isLooping = loopDefault
        self.isSessionActive = true
        await playCurrentSection()
    }

    func playCurrentSection() async {
        guard let section = currentSection else {
            print("PlaybackCoordinator: No current section at index \(currentSectionIndex)")
            return
        }

        print("PlaybackCoordinator: Playing section '\(section.title)' of '\(section.songTitle)' (ID: \(section.appleMusicID))")

        configureAudioSession()

        // Stop any current playback
        stopCurrentPlayback()

        // TODO: Re-enable once MPMediaQuery crash is resolved
        // Local track detection disabled — MPMediaLibrary crashes on iOS 26.4
        if false, let player = findLocalTrack(appleMusicID: section.appleMusicID) {
            print("PlaybackCoordinator: Using AVFoundation (local track)")
            currentEngine = .avFoundation(player)
            avPlayer = player
            rateControlAvailable = true

            if countdownSeconds > 0 {
                await runCountdown()
            }

            player.enableRate = true
            player.rate = playbackRate
            player.currentTime = section.startTime
            player.play()
            isPlaying = true
            startMonitoring()
            return
        }

        // Fall back to MusicKit streaming
        let authDesc: String
        switch musicService.authorizationStatus {
        case .authorized: authDesc = "authorized"
        case .denied: authDesc = "denied"
        case .notDetermined: authDesc = "notDetermined"
        case .restricted: authDesc = "restricted"
        @unknown default: authDesc = "unknown"
        }
        debugStatus = "Auth: \(authDesc), looking up: \(section.songTitle)"
        let song = await musicService.lookupSong(byID: section.appleMusicID, title: section.songTitle)
        guard let song else {
            debugStatus = musicService.lookupDebug
            playbackError = "Song not found: \(musicService.lookupDebug)"
            return
        }

        debugStatus = "Found: \(song.title) — calling play()"
        currentEngine = .musicKit(song)
        rateControlAvailable = false

        if countdownSeconds > 0 {
            await runCountdown()
        }

        await musicService.play(song: song, startTime: section.startTime)
        if let error = musicService.lastError {
            debugStatus = "Play error: \(error)"
            playbackError = error
        } else {
            debugStatus = "Playing via MusicKit"
            isPlaying = true
            playbackError = nil
            startMonitoring()
        }
    }

    private func runCountdown() async {
        isCountingDown = true
        countdownRemaining = countdownSeconds
        while countdownRemaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            countdownRemaining -= 1
        }
        isCountingDown = false
    }

    func pause() {
        switch currentEngine {
        case .avFoundation(let player):
            player.pause()
        case .musicKit:
            musicService.pause()
        case nil:
            break
        }
        isPlaying = false
    }

    func resume() async {
        switch currentEngine {
        case .avFoundation(let player):
            player.rate = playbackRate
            player.play()
            isPlaying = true
        case .musicKit:
            await musicService.resume()
            isPlaying = true
        case nil:
            break
        }
    }

    func togglePlayPause() async {
        if isPlaying {
            pause()
        } else {
            await resume()
        }
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if case .avFoundation(let player) = currentEngine, player.isPlaying {
            player.rate = rate
        }
    }

    func nextSection() async {
        guard currentSectionIndex < sections.count - 1 else {
            endSession()
            return
        }
        currentSectionIndex += 1
        await playCurrentSection()
    }

    func previousSection() async {
        guard currentSectionIndex > 0 else { return }
        currentSectionIndex -= 1
        await playCurrentSection()
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    func endSession() {
        stopCurrentPlayback()
        isPlaying = false
        isSessionActive = false
        isCountingDown = false
        countdownRemaining = 0
        sections = []
        currentSectionIndex = 0
        currentEngine = nil
        stopMonitoring()
    }

    private func stopCurrentPlayback() {
        switch currentEngine {
        case .avFoundation(let player):
            player.stop()
        case .musicKit:
            musicService.stop()
        case nil:
            break
        }
    }

    // MARK: - Local Track Detection

    private func findLocalTrack(appleMusicID: String) -> AVAudioPlayer? {
        // Check media library authorization first
        let authStatus = MPMediaLibrary.authorizationStatus()
        print("PlaybackCoordinator: Media library auth status: \(authStatus.rawValue)")
        guard authStatus == .authorized else {
            print("PlaybackCoordinator: Media library not authorized, skipping local track lookup")
            return nil
        }

        print("PlaybackCoordinator: Searching local library for ID \(appleMusicID)")

        // Query the local media library for a track matching this Apple Music ID
        // MPMediaItemPropertyPlaybackStoreID matches the Apple Music catalog ID
        let predicate = MPMediaPropertyPredicate(
            value: appleMusicID,
            forProperty: MPMediaItemPropertyPlaybackStoreID,
            comparisonType: .equalTo
        )
        let query = MPMediaQuery()
        query.addFilterPredicate(predicate)

        guard let item = query.items?.first else {
            print("PlaybackCoordinator: No local item found")
            return nil
        }

        guard let assetURL = item.assetURL else {
            print("PlaybackCoordinator: Item found but no assetURL (DRM protected or cloud-only)")
            return nil
        }

        print("PlaybackCoordinator: Found local track at \(assetURL)")

        do {
            let player = try AVAudioPlayer(contentsOf: assetURL)
            player.prepareToPlay()
            return player
        } catch {
            print("PlaybackCoordinator: Failed to create AVAudioPlayer: \(error)")
            return nil
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
                    await self.checkEndTime()
                }
            }
        }
    }

    private func updatePlaybackTime() {
        switch currentEngine {
        case .avFoundation(let player):
            currentPlaybackTime = player.currentTime
        case .musicKit:
            currentPlaybackTime = musicService.currentPlaybackTime
            debugStatus = musicService.playerStateDebug
        case nil:
            break
        }
    }

    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func checkEndTime() async {
        guard let section = currentSection, let endTime = section.endTime else { return }
        guard currentPlaybackTime >= endTime else { return }

        if isLooping {
            seekToStart(section)
        } else {
            pause()
            try? await Task.sleep(for: .milliseconds(500))
            await nextSection()
        }
    }

    private func seekToStart(_ section: Section) {
        switch currentEngine {
        case .avFoundation(let player):
            player.currentTime = section.startTime
        case .musicKit:
            musicService.seek(to: section.startTime)
        case nil:
            break
        }
    }
}
