import SwiftUI

@main
struct WoodshedApp: App {
    @State private var storageService = StorageService()
    @State private var musicService = MusicKitService()
    @State private var playbackCoordinator: PlaybackCoordinator

    init() {
        let music = MusicKitService()
        _musicService = State(initialValue: music)
        _playbackCoordinator = State(initialValue: PlaybackCoordinator(musicService: music))
    }

    var body: some Scene {
        WindowGroup {
            SetlistLibraryView()
                .environment(storageService)
                .environment(musicService)
                .environment(playbackCoordinator)
                .task {
                    await musicService.requestAuthorization()
                }
        }
    }
}
