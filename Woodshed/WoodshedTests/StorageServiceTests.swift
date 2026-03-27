import Testing
import Foundation
@testable import Woodshed

@Suite("StorageService Tests")
struct StorageServiceTests {

    private func makeTempStorage() -> (StorageService, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WoodshedTests-\(UUID().uuidString)")
        return (StorageService(baseURL: tempDir), tempDir)
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test func saveAndLoadSetlist() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        let setlist = Setlist(title: "Test Setlist")
        storage.save(setlist)

        #expect(storage.setlists.count == 1)
        #expect(storage.setlists[0].title == "Test Setlist")

        // Reload from disk
        storage.loadAllSetlists()
        #expect(storage.setlists.count == 1)
        #expect(storage.setlists[0].id == setlist.id)
    }

    @Test func saveSetlistWithSections() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        var setlist = Setlist(title: "Appetite")
        setlist.sections = [
            Section(title: "Intro", songTitle: "Welcome to the Jungle", appleMusicID: "123", startTime: 0, endTime: 15, instrument: "Guitar"),
            Section(title: "Verse 1", songTitle: "Welcome to the Jungle", appleMusicID: "123", startTime: 15, endTime: 45, instrument: "Guitar", role: "Rhythm"),
        ]
        storage.save(setlist)

        // Reload from disk
        let fresh = StorageService(baseURL: tempDir)
        #expect(fresh.setlists.count == 1)
        #expect(fresh.setlists[0].sections.count == 2)
        #expect(fresh.setlists[0].sections[1].role == "Rhythm")
    }

    @Test func deleteSetlist() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        let setlist = Setlist(title: "To Delete")
        storage.save(setlist)
        #expect(storage.setlists.count == 1)

        storage.delete(setlist)
        #expect(storage.setlists.isEmpty)

        // Reload from disk — should still be empty
        storage.loadAllSetlists()
        #expect(storage.setlists.isEmpty)
    }

    @Test func updateExistingSetlist() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        var setlist = Setlist(title: "Original")
        storage.save(setlist)

        setlist.title = "Updated"
        storage.save(setlist)

        #expect(storage.setlists.count == 1)
        #expect(storage.setlists[0].title == "Updated")
    }

    @Test func multipleSetlists() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        storage.save(Setlist(title: "First"))
        storage.save(Setlist(title: "Second"))
        storage.save(Setlist(title: "Third"))

        #expect(storage.setlists.count == 3)

        let fresh = StorageService(baseURL: tempDir)
        #expect(fresh.setlists.count == 3)
    }

    @Test func settingsSaveAndLoad() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        storage.settings.defaultInstrument = "Bass"
        storage.settings.countdownSeconds = 3
        storage.settings.tabDisplayMode = .scroll
        storage.saveSettings()

        let fresh = StorageService(baseURL: tempDir)
        #expect(fresh.settings.defaultInstrument == "Bass")
        #expect(fresh.settings.countdownSeconds == 3)
        #expect(fresh.settings.tabDisplayMode == .scroll)
    }

    @Test func tabImageSaveAndRetrieve() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        let imageData = Data("fake-image-data".utf8)
        storage.saveTabImage(imageData, filename: "test-tab.jpg")

        let url = storage.tabImageURL(for: "test-tab.jpg")
        #expect(url != nil)

        if let url {
            let loaded = try? Data(contentsOf: url)
            #expect(loaded == imageData)
        }
    }

    @Test func tabImageMissingReturnsNil() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        let url = storage.tabImageURL(for: "nonexistent.jpg")
        #expect(url == nil)
    }

    @Test func slugBasedFilenames() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        storage.save(Setlist(title: "Appetite for Destruction"))

        let setlistsDir = tempDir.appendingPathComponent("Documents/setlists")
        let files = try? FileManager.default.contentsOfDirectory(at: setlistsDir, includingPropertiesForKeys: nil)
        let filenames = files?.map { $0.lastPathComponent } ?? []
        #expect(filenames.contains("appetite-for-destruction.json"))
    }

    @Test func renameDeletesOldFile() {
        let (storage, tempDir) = makeTempStorage()
        defer { cleanup(tempDir) }

        var setlist = Setlist(title: "Old Name")
        storage.save(setlist)

        let setlistsDir = tempDir.appendingPathComponent("Documents/setlists")

        // Old file exists
        var files = (try? FileManager.default.contentsOfDirectory(at: setlistsDir, includingPropertiesForKeys: nil))?.map { $0.lastPathComponent } ?? []
        #expect(files.contains("old-name.json"))

        // Rename
        setlist.title = "New Name"
        storage.save(setlist)

        files = (try? FileManager.default.contentsOfDirectory(at: setlistsDir, includingPropertiesForKeys: nil))?.map { $0.lastPathComponent } ?? []
        #expect(files.contains("new-name.json"))
        #expect(!files.contains("old-name.json"))
        #expect(storage.setlists.count == 1)
    }
}
