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

            if let song = coordinator.currentJamSong {
                Text(song.title)
                    .font(.largeTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(song.instrument)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Text("\(coordinator.currentSongIndex + 1) of \(coordinator.songs.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)

                Spacer()

                Text(Section.formatTime(coordinator.currentPlaybackTime))
                    .font(.system(.title, design: .monospaced))
                    .foregroundStyle(.secondary)

                // Scrubber
                Slider(value: Binding(
                    get: { coordinator.currentPlaybackTime },
                    set: { coordinator.seek(to: $0) }
                ), in: 0...max(coordinator.currentPlaybackTime + 60, 300))
                .padding(.horizontal, 40)
                .padding(.top, 8)
            } else {
                ProgressView("Loading...")
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

            if let error = coordinator.playbackError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
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
