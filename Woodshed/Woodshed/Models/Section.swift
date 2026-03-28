import Foundation

struct Section: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var startTime: TimeInterval
    var endTime: TimeInterval?
    var role: String?
    var tabImageFilename: String?
    var notes: String?

    init(id: UUID = UUID(), title: String, startTime: TimeInterval, endTime: TimeInterval? = nil, role: String? = nil, tabImageFilename: String? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.role = role
        self.tabImageFilename = tabImageFilename
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(TimeInterval.self, forKey: .endTime)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        tabImageFilename = try container.decodeIfPresent(String.self, forKey: .tabImageFilename)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    var duration: TimeInterval? {
        guard let endTime else { return nil }
        return endTime - startTime
    }

    var formattedTimeRange: String {
        let start = Self.formatTime(startTime)
        if let endTime {
            return "\(start) – \(Self.formatTime(endTime))"
        }
        return "\(start) – end"
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        return Self.formatTime(duration)
    }

    static func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
