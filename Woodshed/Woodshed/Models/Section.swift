import Foundation

struct Section: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var startTime: TimeInterval
    var endTime: TimeInterval?
    var role: String?
    var tabImageFilename: String?
    var notes: String?

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
