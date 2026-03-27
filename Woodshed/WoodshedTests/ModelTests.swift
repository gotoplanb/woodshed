import Testing
import Foundation
@testable import Woodshed

@Suite("Model Tests")
struct ModelTests {

    @Test func sectionFormattedTimeRange() {
        let section = Section(
            title: "Intro",
            songTitle: "Welcome to the Jungle",
            appleMusicID: "123",
            startTime: 32.5,
            endTime: 75.0,
            instrument: "Guitar"
        )
        #expect(section.formattedTimeRange == "0:32 – 1:15")
        #expect(section.duration == 42.5)
    }

    @Test func sectionOpenEndedTimeRange() {
        let section = Section(
            title: "Outro",
            songTitle: "Paradise City",
            appleMusicID: "456",
            startTime: 180,
            instrument: "Guitar"
        )
        #expect(section.formattedTimeRange == "3:00 – end")
        #expect(section.duration == nil)
    }

    @Test func setlistSlug() {
        let setlist = Setlist(title: "Appetite for Destruction")
        #expect(setlist.slug == "appetite-for-destruction")
    }

    @Test func setlistSlugStripsSpecialChars() {
        let setlist = Setlist(title: "GN'R Lies (Deluxe)")
        #expect(setlist.slug == "gnr-lies-deluxe")
    }

    @Test func sectionsBySongGrouping() {
        let setlist = Setlist(title: "Test", sections: [
            Section(title: "Intro", songTitle: "Song A", appleMusicID: "1", startTime: 0, instrument: "Guitar"),
            Section(title: "Verse", songTitle: "Song B", appleMusicID: "2", startTime: 0, instrument: "Guitar"),
            Section(title: "Chorus", songTitle: "Song A", appleMusicID: "1", startTime: 30, instrument: "Guitar"),
        ])
        let groups = setlist.sectionsBySong
        #expect(groups.count == 2)
        #expect(groups[0].songTitle == "Song A")
        #expect(groups[0].sections.count == 2)
        #expect(groups[1].songTitle == "Song B")
        #expect(groups[1].sections.count == 1)
    }

    @Test func setlistCodableRoundTrip() throws {
        let original = Setlist(title: "Test Setlist", sections: [
            Section(title: "Intro", songTitle: "Song", appleMusicID: "123", startTime: 10, endTime: 30, instrument: "Guitar", role: "Lead"),
        ])
        let data = try JSONEncoder.woodshed.encode(original)
        let decoded = try JSONDecoder.woodshed.decode(Setlist.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.sections.count == 1)
        #expect(decoded.sections[0].startTime == 10)
        #expect(decoded.sections[0].role == "Lead")
    }

    @Test func appSettingsCodableRoundTrip() throws {
        var settings = AppSettings()
        settings.countdownSeconds = 3
        settings.tabDisplayMode = .scroll
        let data = try JSONEncoder.woodshed.encode(settings)
        let decoded = try JSONDecoder.woodshed.decode(AppSettings.self, from: data)
        #expect(decoded.countdownSeconds == 3)
        #expect(decoded.tabDisplayMode == .scroll)
    }
}
