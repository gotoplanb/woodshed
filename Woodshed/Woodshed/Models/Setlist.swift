import Foundation

struct Setlist: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var sections: [Section] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var slug: String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    /// Sections grouped by songTitle, preserving order of first appearance.
    var sectionsBySong: [(songTitle: String, sections: [Section])] {
        var seen: [String] = []
        var groups: [String: [Section]] = [:]
        for section in sections {
            if !seen.contains(section.songTitle) {
                seen.append(section.songTitle)
            }
            groups[section.songTitle, default: []].append(section)
        }
        return seen.map { (songTitle: $0, sections: groups[$0]!) }
    }
}
