import Testing
import Foundation
@testable import Woodshed

@Suite("PlaybackCoordinator")
@MainActor
struct PlaybackCoordinatorTests {

    private func makeCoordinator() -> PlaybackCoordinator {
        let spy = SpyMusicPlayer()
        let musicService = MusicKitService(player: spy)
        return PlaybackCoordinator(musicService: musicService)
    }

    private func makeSections() -> [Section] {
        [
            Section(title: "Intro", songTitle: "Song A", appleMusicID: "1", startTime: 0, endTime: 15, instrument: "Guitar"),
            Section(title: "Verse", songTitle: "Song A", appleMusicID: "1", startTime: 15, endTime: 45, instrument: "Guitar"),
            Section(title: "Chorus", songTitle: "Song A", appleMusicID: "1", startTime: 45, endTime: 75, instrument: "Guitar"),
        ]
    }

    @Test("initial state is inactive")
    func initialState() {
        let coordinator = makeCoordinator()
        #expect(coordinator.isSessionActive == false)
        #expect(coordinator.isPlaying == false)
        #expect(coordinator.currentSection == nil)
        #expect(coordinator.sections.isEmpty)
    }

    @Test("endSession resets all state")
    func endSessionResetsState() async {
        let coordinator = makeCoordinator()
        // Manually set up session state without calling startSession (which needs MusicKit catalog)
        coordinator.sections = makeSections()
        coordinator.currentSectionIndex = 1
        coordinator.isPlaying = true
        coordinator.isLooping = true

        coordinator.endSession()

        #expect(coordinator.isSessionActive == false)
        #expect(coordinator.isPlaying == false)
        #expect(coordinator.currentSectionIndex == 0)
        #expect(coordinator.sections.isEmpty)
    }

    @Test("toggleLoop flips loop state")
    func toggleLoop() {
        let coordinator = makeCoordinator()
        #expect(coordinator.isLooping == false)

        coordinator.toggleLoop()
        #expect(coordinator.isLooping == true)

        coordinator.toggleLoop()
        #expect(coordinator.isLooping == false)
    }

    @Test("currentSection returns correct section by index")
    func currentSectionByIndex() {
        let coordinator = makeCoordinator()
        let sections = makeSections()
        coordinator.sections = sections
        coordinator.currentSectionIndex = 1

        #expect(coordinator.currentSection?.title == "Verse")
    }

    @Test("currentSection returns nil for out-of-bounds index")
    func currentSectionOutOfBounds() {
        let coordinator = makeCoordinator()
        coordinator.sections = makeSections()
        coordinator.currentSectionIndex = 99

        #expect(coordinator.currentSection == nil)
    }

    @Test("sectionProgress computes correctly")
    func sectionProgress() {
        let coordinator = makeCoordinator()
        coordinator.sections = makeSections()
        coordinator.currentSectionIndex = 0
        // Section 0: startTime=0, endTime=15, duration=15
        coordinator.currentPlaybackTime = 7.5

        #expect(coordinator.sectionProgress == 0.5)
    }

    @Test("sectionProgress clamps to 0-1")
    func sectionProgressClamped() {
        let coordinator = makeCoordinator()
        coordinator.sections = makeSections()
        coordinator.currentSectionIndex = 0
        coordinator.currentPlaybackTime = 100 // way past endTime

        #expect(coordinator.sectionProgress == 1.0)
    }

    @Test("pause sets isPlaying to false")
    func pauseSetsState() {
        let coordinator = makeCoordinator()
        coordinator.isPlaying = true
        coordinator.pause()

        #expect(coordinator.isPlaying == false)
    }

    @Test("rateControlAvailable defaults to false")
    func rateControlDefault() {
        let coordinator = makeCoordinator()
        #expect(coordinator.rateControlAvailable == false)
    }

    @Test("countdown defaults to not counting down")
    func countdownDefaults() {
        let coordinator = makeCoordinator()
        #expect(coordinator.isCountingDown == false)
        #expect(coordinator.countdownRemaining == 0)
        #expect(coordinator.countdownSeconds == 0)
    }

    @Test("endSession stops countdown state")
    func endSessionStopsCountdown() {
        let coordinator = makeCoordinator()
        coordinator.isCountingDown = true
        coordinator.countdownRemaining = 3
        coordinator.endSession()

        #expect(coordinator.isCountingDown == false)
    }
}

