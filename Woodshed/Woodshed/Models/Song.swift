import Foundation

struct SongEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var appleMusicID: String
    var instrument: String = "Guitar"
    var sections: [Section] = []
}
