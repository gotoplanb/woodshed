import Foundation
import Observation

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

    private let musicService: MusicKitService
    private var monitorTimer: Timer?
    private var countdownTimer: Timer?

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

    func startSession(sections: [Section], startIndex: Int, loopDefault: Bool) async {
        self.sections = sections
        self.currentSectionIndex = startIndex
        self.isLooping = loopDefault
        self.isSessionActive = true
        await playCurrentSection()
    }

    func playCurrentSection() async {
        guard let section = currentSection else { return }

        let song = await musicService.lookupSong(byID: section.appleMusicID)
        guard let song else {
            print("Could not find song for appleMusicID: \(section.appleMusicID)")
            return
        }

        // TODO: Phase 6 — detect local vs streaming, use AVFoundation for local
        rateControlAvailable = false

        if countdownSeconds > 0 {
            await runCountdown()
        }

        await musicService.play(song: song, startTime: section.startTime)
        isPlaying = true
        startMonitoring()
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
        musicService.stop()
        isPlaying = false
        isSessionActive = false
        isCountingDown = false
        countdownRemaining = 0
        sections = []
        currentSectionIndex = 0
        stopMonitoring()
    }

    // MARK: - Position Monitoring

    private func startMonitoring() {
        stopMonitoring()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.currentPlaybackTime = self.musicService.currentPlaybackTime
                await self.checkEndTime()
            }
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
            musicService.seek(to: section.startTime)
        } else {
            musicService.pause()
            isPlaying = false
            try? await Task.sleep(for: .milliseconds(500))
            await nextSection()
        }
    }
}
