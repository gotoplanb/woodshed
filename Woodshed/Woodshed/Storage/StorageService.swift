import Foundation

@Observable
final class StorageService {
    private(set) var setlists: [Setlist] = []
    var settings: AppSettings = AppSettings()
    var iCloudAvailable: Bool { iCloudURL != nil }

    private let localBaseURL: URL
    private let iCloudURL: URL?
    private var metadataQuery: NSMetadataQuery?

    private var baseURL: URL {
        iCloudURL ?? localBaseURL
    }

    private var setlistsURL: URL {
        baseURL.appendingPathComponent("Documents/setlists")
    }

    private var tabsURL: URL {
        baseURL.appendingPathComponent("Documents/tabs")
    }

    private var settingsFileURL: URL {
        baseURL.appendingPathComponent("Documents/settings.json")
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Woodshed")
        self.localBaseURL = appSupport

        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.zeromissionllc.woodshed") {
            self.iCloudURL = containerURL
        } else {
            self.iCloudURL = nil
        }

        createDirectories()
        seedIfEmpty()
        loadAllSetlists()
        loadSettings()
        startWatchingForChanges()
    }

    /// Testable initializer that uses a local directory with no iCloud.
    init(baseURL: URL) {
        self.localBaseURL = baseURL
        self.iCloudURL = nil
        createDirectories()
        loadAllSetlists()
        loadSettings()
    }

    deinit {
        metadataQuery?.stop()
    }

    // MARK: - Setlist CRUD

    func loadAllSetlists() {
        let url = setlistsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            var loaded: [Setlist] = []
            for file in files {
                if let setlist = readSetlist(at: file) {
                    loaded.append(setlist)
                }
            }
            self.setlists = loaded.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("Failed to list setlists: \(error)")
        }
    }

    func save(_ setlist: Setlist) {
        var updated = setlist
        updated.updatedAt = Date()

        // If title (slug) changed, delete the old file to avoid orphans
        if let existing = setlists.first(where: { $0.id == updated.id }), existing.slug != updated.slug {
            let oldFileURL = setlistsURL.appendingPathComponent("\(existing.slug).json")
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(writingItemAt: oldFileURL, options: .forDeleting, error: &error) { coordURL in
                try? FileManager.default.removeItem(at: coordURL)
            }
        }

        let fileURL = setlistsURL.appendingPathComponent("\(updated.slug).json")
        do {
            let data = try JSONEncoder.woodshed.encode(updated)
            coordinatedWrite(data: data, to: fileURL)
        } catch {
            print("Failed to encode setlist: \(error)")
        }

        if let index = setlists.firstIndex(where: { $0.id == updated.id }) {
            setlists[index] = updated
        } else {
            setlists.insert(updated, at: 0)
        }
    }

    func delete(_ setlist: Setlist) {
        let fileURL = setlistsURL.appendingPathComponent("\(setlist.slug).json")
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: &error) { coordURL in
            try? FileManager.default.removeItem(at: coordURL)
        }
        setlists.removeAll { $0.id == setlist.id }
    }

    // MARK: - Settings

    func loadSettings() {
        let url = settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        if let data = coordinatedRead(from: url) {
            if let decoded = try? JSONDecoder.woodshed.decode(AppSettings.self, from: data) {
                self.settings = decoded
            }
        }
    }

    func saveSettings() {
        do {
            let data = try JSONEncoder.woodshed.encode(settings)
            coordinatedWrite(data: data, to: settingsFileURL)
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }

    // MARK: - Tab Images

    func saveTabImage(_ imageData: Data, filename: String) {
        let fileURL = tabsURL.appendingPathComponent(filename)
        coordinatedWrite(data: imageData, to: fileURL)
    }

    func tabImageURL(for filename: String) -> URL? {
        let fileURL = tabsURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    // MARK: - File Coordination

    private func readSetlist(at url: URL) -> Setlist? {
        guard let data = coordinatedRead(from: url) else { return nil }
        return try? JSONDecoder.woodshed.decode(Setlist.self, from: data)
    }

    private func coordinatedRead(from url: URL) -> Data? {
        let coordinator = NSFileCoordinator()
        var data: Data?
        var error: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { coordURL in
            data = try? Data(contentsOf: coordURL)
        }
        if let error {
            print("Coordinated read failed: \(error)")
        }
        return data
    }

    private func coordinatedWrite(data: Data, to url: URL) {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { coordURL in
            try? data.write(to: coordURL, options: .atomic)
        }
        if let error {
            print("Coordinated write failed: \(error)")
        }
    }

    // MARK: - Setup

    private func createDirectories() {
        try? FileManager.default.createDirectory(at: setlistsURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: tabsURL, withIntermediateDirectories: true)
    }

    // MARK: - Seed Data

    private func seedIfEmpty() {
        let url = setlistsURL
        let hasFiles = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil))?.contains { $0.pathExtension == "json" } ?? false
        guard !hasFiles else { return }

        // Copy bundled seed setlists into storage
        for name in ["appetite-for-destruction", "test-playback"] {
            if let seedURL = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: seedURL) {
                let destURL = setlistsURL.appendingPathComponent("\(name).json")
                coordinatedWrite(data: data, to: destURL)
            }
        }
    }

    // MARK: - iCloud Sync

    private func startWatchingForChanges() {
        guard iCloudURL != nil else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.json'", NSMetadataItemFSNameKey)

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.loadAllSetlists()
            self?.loadSettings()
        }

        query.start()
        metadataQuery = query
    }
}

// MARK: - JSON Coding

extension JSONEncoder {
    static let woodshed: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let woodshed: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
