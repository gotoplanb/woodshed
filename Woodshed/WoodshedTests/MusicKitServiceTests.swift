import Testing
import Foundation
import MusicKit
@testable import Woodshed

@Observable
final class SpyMusicPlayer: MusicPlayerProtocol {
    var playbackTime: TimeInterval = 0
    var queue: ApplicationMusicPlayer.Queue = ApplicationMusicPlayer.Queue()
    var operations: [String] = []
    var playbackTimeAtPlay: TimeInterval?

    func play() async throws {
        playbackTimeAtPlay = playbackTime
        operations.append("play")
    }

    func pause() {
        operations.append("pause")
    }

    func stop() {
        operations.append("stop")
    }
}

@Suite("MusicKitService")
@MainActor
struct MusicKitServiceTests {

    @Test("play sequence: queue, play(), then seek")
    func playSeeksAfterPlay() async {
        let spy = SpyMusicPlayer()
        spy.queue = ApplicationMusicPlayer.Queue()
        try? await spy.play()
        spy.playbackTime = 30.0

        #expect(spy.playbackTimeAtPlay == 0)
        #expect(spy.playbackTime == 30.0)
    }

    @Test("stop delegates to player and clears isPlaying")
    func stopResetsState() {
        let spy = SpyMusicPlayer()
        let service = MusicKitService(player: spy)
        service.stop()

        #expect(service.isPlaying == false)
        #expect(spy.operations == ["stop"])
    }

    @Test("pause delegates to player and clears isPlaying")
    func pauseSetsState() {
        let spy = SpyMusicPlayer()
        let service = MusicKitService(player: spy)
        service.pause()

        #expect(service.isPlaying == false)
        #expect(spy.operations == ["pause"])
    }

    @Test("seek sets player playbackTime")
    func seekSetsTime() {
        let spy = SpyMusicPlayer()
        let service = MusicKitService(player: spy)
        service.seek(to: 45.0)

        #expect(spy.playbackTime == 45.0)
    }

    @Test("resume delegates to player")
    func resumeDelegatesToPlayer() async {
        let spy = SpyMusicPlayer()
        let service = MusicKitService(player: spy)
        await service.resume()

        #expect(service.isPlaying == true)
        #expect(spy.operations == ["play"])
    }
}
