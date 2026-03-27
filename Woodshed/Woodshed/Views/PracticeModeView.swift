import SwiftUI

struct PracticeModeView: View {
    @Environment(StorageService.self) private var storage
    @Environment(PlaybackCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    let setlistID: UUID
    let startIndex: Int
    let loopDefault: Bool
    @State private var errorMessage: String?
    @State private var sessionStarted = false

    private var setlist: Setlist? {
        storage.setlists.first { $0.id == setlistID }
    }

    var body: some View {
        VStack(spacing: 20) {
            if let errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundStyle(.red)
            } else if !sessionStarted {
                ProgressView("Starting session...")
            } else if let section = coordinator.currentSection {
                practiceContent(section)
            } else {
                Text("No section loaded")
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
            sessionStarted = true
            if coordinator.currentSection == nil {
                errorMessage = "Could not start playback. Check Apple Music authorization."
            }
        }
    }

    private func practiceContent(_ section: Section) -> some View {
        VStack(spacing: 0) {
            // Top: Tab image or fallback
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

            Divider()

            VStack(spacing: 16) {
                Text(section.songTitle)
                    .font(.headline)
                Text(section.title)
                    .foregroundStyle(.secondary)

                Text(Section.formatTime(coordinator.currentPlaybackTime))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                if let error = coordinator.playbackError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                ProgressView(value: coordinator.sectionProgress)
                    .padding(.horizontal)

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
                    Button {
                        coordinator.toggleLoop()
                    } label: {
                        Image(systemName: coordinator.isLooping ? "repeat.1" : "repeat")
                            .foregroundStyle(coordinator.isLooping ? .primary : .secondary)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Picker("Speed", selection: Binding(
                        get: { coordinator.playbackRate },
                        set: { coordinator.setRate($0) }
                    )) {
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
                    Text("Slow playback works with downloaded tracks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}
