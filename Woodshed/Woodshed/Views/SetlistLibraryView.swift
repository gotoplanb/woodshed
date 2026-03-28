import SwiftUI

struct SetlistLibraryView: View {
    @Environment(StorageService.self) private var storage
    @State private var showingPlaylistPicker = false
    @State private var renamingSetlist: Setlist?
    @State private var renameTitle = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(storage.setlists) { setlist in
                    NavigationLink(destination: SetlistDetailView(setlistID: setlist.id)) {
                        VStack(alignment: .leading) {
                            Text(setlist.title)
                            Text("\(setlist.songs.count) songs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button {
                            renameTitle = setlist.title
                            renamingSetlist = setlist
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            storage.delete(setlist)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: deleteSetlists)
            }
            .refreshable {
                storage.loadAllSetlists()
            }
            .navigationTitle("Hermit Jam")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingPlaylistPicker = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            .overlay {
                if storage.setlists.isEmpty {
                    ContentUnavailableView("No Setlists", systemImage: "music.note.list", description: Text("Import a playlist from Apple Music to get started."))
                }
            }
            .sheet(isPresented: $showingPlaylistPicker) {
                PlaylistPickerView()
            }
            .alert("Rename Setlist", isPresented: Binding(
                get: { renamingSetlist != nil },
                set: { if !$0 { renamingSetlist = nil } }
            )) {
                TextField("Title", text: $renameTitle)
                Button("Rename") {
                    guard var setlist = renamingSetlist,
                          !renameTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    setlist.title = renameTitle.trimmingCharacters(in: .whitespaces)
                    storage.save(setlist)
                    renamingSetlist = nil
                }
                Button("Cancel", role: .cancel) {
                    renamingSetlist = nil
                }
            }
        }
    }

    private func deleteSetlists(at offsets: IndexSet) {
        for index in offsets {
            storage.delete(storage.setlists[index])
        }
    }
}
