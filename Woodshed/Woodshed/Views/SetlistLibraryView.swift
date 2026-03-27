import SwiftUI

struct SetlistLibraryView: View {
    @Environment(StorageService.self) private var storage
    @State private var showingNewSetlist = false
    @State private var newSetlistTitle = ""
    @State private var renamingSetlist: Setlist?
    @State private var renameTitle = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(storage.setlists) { setlist in
                    NavigationLink(destination: SetlistDetailView(setlistID: setlist.id)) {
                        VStack(alignment: .leading) {
                            Text(setlist.title)
                            Text("\(setlist.sections.count) sections")
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
            .navigationTitle("Woodshed")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewSetlist = true
                    } label: {
                        Image(systemName: "plus")
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
                    ContentUnavailableView("No Setlists", systemImage: "music.note.list", description: Text("Tap + to create your first setlist."))
                }
            }
            .alert("New Setlist", isPresented: $showingNewSetlist) {
                TextField("Title", text: $newSetlistTitle)
                Button("Create") {
                    guard !newSetlistTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let setlist = Setlist(title: newSetlistTitle.trimmingCharacters(in: .whitespaces))
                    storage.save(setlist)
                    newSetlistTitle = ""
                }
                Button("Cancel", role: .cancel) {
                    newSetlistTitle = ""
                }
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
