import SwiftUI

struct JamModeView: View {
    @Environment(StorageService.self) private var storage
    @Environment(PlaybackCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    let setlistID: UUID
    let startIndex: Int

    private var setlist: Setlist? {
        storage.setlists.first { $0.id == setlistID }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Current song info
            if let song = coordinator.currentSong {
                Text(song.title)
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)

                Text("\(coordinator.currentSongIndex + 1) of \(coordinator.songs.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer()

                // Progress
                Text(Section.formatTime(coordinator.currentPlaybackTime))
                    .font(.system(.title, design: .monospaced))
                    .foregroundStyle(.secondary)

                ProgressView(value: coordinator.songProgress)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            } else {
                Text("Loading...")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // Transport controls
            HStack(spacing: 50) {
                Button { Task { await coordinator.previousSong() } } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }

                Button { Task { await coordinator.togglePlayPause() } } label: {
                    Image(systemName: coordinator.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 50))
                }

                Button { Task { await coordinator.nextSong() } } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .padding(.bottom, 40)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    coordinator.endSession()
                    dismiss()
                }
            }
        }
        .task {
            guard let setlist, !coordinator.isSessionActive else { return }
            await coordinator.startJamSession(songs: setlist.songs, startIndex: startIndex)
        }
    }
}
