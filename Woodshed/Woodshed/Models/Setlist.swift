import Foundation

struct Setlist: Codable, Identifiable {
    var id: UUID
    var title: String
    var songs: [SongEntry]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, songs: [SongEntry] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.songs = songs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        songs = (try? container.decode([SongEntry].self, forKey: .songs)) ?? []
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
    }

    var slug: String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
