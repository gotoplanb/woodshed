import Foundation

struct Setlist: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var songs: [SongEntry] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var slug: String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
