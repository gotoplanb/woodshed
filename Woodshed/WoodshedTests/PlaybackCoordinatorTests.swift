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

    private func makeSongEntry() -> SongEntry {
        SongEntry(
            title: "Mr. Brownstone",
            appleMusicID: "123",
            instrument: "Guitar",
            sections: [
                Section(title: "Intro", startTime: 0, endTime: 18),
                Section(title: "Verse", startTime: 18, endTime: 60),
                Section(title: "Chorus", startTime: 60, endTime: 90),
            ]
        )
    }

    @Test("initial state is inactive")
    func initialState() {
        let coordinator = makeCoordinator()
        #expect(coordinator.isSessionActive == false)
        #expect(coordinator.isPlaying == false)
        #expect(coordinator.currentSection == nil)
    }

    @Test("endSession resets all state")
    func endSessionResetsState() {
        let coordinator = makeCoordinator()
        coordinator.isPlaying = true
        coordinator.isSessionActive = true
        coordinator.isLooping = true
        coordinator.currentSong = makeSongEntry()

        coordinator.endSession()

        #expect(coordinator.isSessionActive == false)
        #expect(coordinator.isPlaying == false)
        #expect(coordinator.currentSong == nil)
        #expect(coordinator.songs.isEmpty)
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

    @Test("currentSection returns correct section by index in practice mode")
    func currentSectionByIndex() {
        let coordinator = makeCoordinator()
        coordinator.mode = .practice
        coordinator.currentSong = makeSongEntry()
        coordinator.currentSectionIndex = 1

        #expect(coordinator.currentSection?.title == "Verse")
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

    @Test("seekToSection updates index and seeks")
    func seekToSection() {
        let coordinator = makeCoordinator()
        coordinator.mode = .practice
        coordinator.currentSong = makeSongEntry()
        coordinator.isSessionActive = true
        coordinator.seekToSection(2)
        #expect(coordinator.currentSectionIndex == 2)
    }
}
