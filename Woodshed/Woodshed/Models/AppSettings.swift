import Foundation

struct AppSettings: Codable {
    var defaultInstrument: String = "Guitar"
    var countdownSeconds: Int = 0
    var tabDisplayMode: TabDisplayMode = .fit

    enum TabDisplayMode: String, Codable, CaseIterable, Identifiable {
        case fit, fill, scroll

        var id: String { rawValue }
    }
}
