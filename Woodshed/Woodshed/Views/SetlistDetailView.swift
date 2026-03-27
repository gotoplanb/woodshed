import SwiftUI

struct SetlistDetailView: View {
    @Environment(StorageService.self) private var storage
    let setlistID: UUID
    @State private var practiceStartIndex: Int?
    @State private var practiceLoopDefault = false
    @State private var showPracticeMode = false

    private var setlist: Setlist? {
        storage.setlists.first { $0.id == setlistID }
    }

    var body: some View {
        Group {
            if let setlist {
                content(setlist)
            } else {
                ContentUnavailableView("Setlist Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationDestination(isPresented: $showPracticeMode) {
            if let startIndex = practiceStartIndex {
                PracticeModeView(setlistID: setlistID, startIndex: startIndex, loopDefault: practiceLoopDefault)
            }
        }
    }

    private func content(_ setlist: Setlist) -> some View {
        List {
            ForEach(Array(setlist.sections.enumerated()), id: \.element.id) { index, section in
                NavigationLink(destination: SectionEditorView(setlistID: setlistID, sectionID: section.id)) {
                    sectionRow(section)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        deleteSection(at: index)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        practiceStartIndex = index
                        practiceLoopDefault = true
                        showPracticeMode = true
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .tint(.green)
                }
            }
            .onMove(perform: moveSections)
        }
        .navigationTitle(setlist.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: SectionEditorView(setlistID: setlistID, sectionID: nil)) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            ToolbarItem(placement: .bottomBar) {
                if !setlist.sections.isEmpty {
                    Button {
                        practiceStartIndex = 0
                        practiceLoopDefault = false
                        showPracticeMode = true
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                    }
                }
            }
        }
        .overlay {
            if setlist.sections.isEmpty {
                ContentUnavailableView("No Sections", systemImage: "music.note", description: Text("Tap + to add a section."))
            }
        }
    }

    private func sectionRow(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(section.title)
                Spacer()
                if section.tabImageFilename != nil {
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            HStack {
                Text(section.songTitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(section.instrument)
                    .foregroundStyle(.secondary)
                if let role = section.role {
                    Text("· \(role)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            Text(section.formattedTimeRange)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    private func deleteSection(at index: Int) {
        guard var setlist = setlist else { return }
        setlist.sections.remove(at: index)
        storage.save(setlist)
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        guard var setlist = setlist else { return }
        setlist.sections.move(fromOffsets: source, toOffset: destination)
        storage.save(setlist)
    }
}
