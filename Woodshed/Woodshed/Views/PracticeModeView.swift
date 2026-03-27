import SwiftUI

struct PracticeModeView: View {
    @Environment(StorageService.self) private var storage
    @Environment(PlaybackCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    let setlistID: UUID
    let startIndex: Int
    let loopDefault: Bool

    private var setlist: Setlist? {
        storage.setlists.first { $0.id == setlistID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Tab image or fallback
            if let section = coordinator.currentSection {
                if let tabFilename = section.tabImageFilename {
                    TabImageView(filename: tabFilename)
                } else {
                    VStack {
                        Spacer()
                        Text(section.songTitle)
                            .font(.title)
                        Text(section.title)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.fill.tertiary)
                }
            }

            Divider()

            // Bottom: Controls
            VStack(spacing: 16) {
                if let section = coordinator.currentSection {
                    Text(section.songTitle)
                        .font(.headline)
                    Text(section.title)
                        .foregroundStyle(.secondary)

                    ProgressView(value: coordinator.sectionProgress)
                        .padding(.horizontal)

                    // Transport controls
                    HStack(spacing: 40) {
                        Button { Task { await coordinator.previousSection() } } label: {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }

                        Button { Task { await coordinator.togglePlayPause() } } label: {
                            Image(systemName: coordinator.isPlaying ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                        }

                        Button { Task { await coordinator.nextSection() } } label: {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                    }

                    HStack {
                        // Loop toggle
                        Button {
                            coordinator.toggleLoop()
                        } label: {
                            Image(systemName: coordinator.isLooping ? "repeat.1" : "repeat")
                                .foregroundStyle(coordinator.isLooping ? .primary : .secondary)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        // Speed control
                        Picker("Speed", selection: Bindable(coordinator).playbackRate) {
                            Text("0.5x").tag(Float(0.5))
                            Text("0.75x").tag(Float(0.75))
                            Text("1.0x").tag(Float(1.0))
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .disabled(!coordinator.rateControlAvailable)
                    }
                    .padding(.horizontal)

                    if !coordinator.rateControlAvailable {
                        Text("Slow playback works with downloaded tracks. Buy on iTunes, or purchase from the artist directly and add to your library.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(coordinator.isSessionActive)
        .toolbar {
            if coordinator.isSessionActive {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        coordinator.endSession()
                        dismiss()
                    }
                }
            }
        }
        .overlay {
            if coordinator.isCountingDown {
                ZStack {
                    Color.black.opacity(0.6)
                    Text("\(coordinator.countdownRemaining)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .ignoresSafeArea()
            }
        }
        .task {
            guard let setlist, !coordinator.isSessionActive else { return }
            coordinator.countdownSeconds = storage.settings.countdownSeconds
            await coordinator.startSession(sections: setlist.sections, startIndex: startIndex, loopDefault: loopDefault)
        }
    }
}
