import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    static var hasSeenAbout: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenAbout") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenAbout") }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .padding(.top, 20)

                    Text("Hermit Jam")
                        .font(.largeTitle.bold())

                    Text("A music practice companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        infoRow(icon: "music.note.list", text: "Create playlists in Apple Music, then import them here to practice")

                        infoRow(icon: "repeat", text: "Loop any section of a song to drill it at your own pace")

                        infoRow(icon: "play.fill", text: "Jam mode plays through your setlist like a live set")

                        infoRow(icon: "doc.text", text: "Edit section timestamps in the JSON files on iCloud Drive")
                    }
                    .padding(.horizontal)

                    Divider()

                    VStack(spacing: 12) {
                        Link(destination: URL(string: "https://github.com/gotoplanb/woodshed")!) {
                            Label("View on GitHub", systemImage: "link")
                        }

                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Get Started") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(text)
                .font(.body)
        }
    }
}
