import Foundation

struct SongEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var artist: String
    var appleMusicID: String
    var instrument: String
    var tuning: String
    var sections: [Section]

    init(id: UUID = UUID(), title: String, artist: String = "", appleMusicID: String, instrument: String = "Guitar", tuning: String = "Standard E", sections: [Section] = []) {
        self.id = id
        self.title = title
        self.artist = artist
        self.appleMusicID = appleMusicID
        self.instrument = instrument
        self.tuning = tuning
        self.sections = sections
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        artist = (try? container.decode(String.self, forKey: .artist)) ?? ""
        appleMusicID = try container.decode(String.self, forKey: .appleMusicID)
        instrument = (try? container.decode(String.self, forKey: .instrument)) ?? "Guitar"
        tuning = (try? container.decode(String.self, forKey: .tuning)) ?? "Standard E"
        sections = (try? container.decode([Section].self, forKey: .sections)) ?? []
    }
}
