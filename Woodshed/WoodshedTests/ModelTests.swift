import Testing
import Foundation
@testable import Woodshed

@Suite("Model Tests")
struct ModelTests {

    @Test func sectionFormattedTimeRange() {
        let section = Section(
            title: "Intro",
            startTime: 32.5,
            endTime: 75.0
        )
        #expect(section.formattedTimeRange == "0:32 – 1:15")
        #expect(section.duration == 42.5)
    }

    @Test func sectionOpenEndedTimeRange() {
        let section = Section(
            title: "Outro",
            startTime: 180
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

    @Test func songWithSections() {
        let song = SongEntry(
            title: "Mr. Brownstone",
            appleMusicID: "123",
            instrument: "Guitar",
            sections: [
                Section(title: "Intro", startTime: 0, endTime: 18),
                Section(title: "Verse", startTime: 18, endTime: 60),
            ]
        )
        #expect(song.sections.count == 2)
        #expect(song.sections[0].title == "Intro")
    }

    @Test func setlistWithSongs() {
        let setlist = Setlist(title: "Test", songs: [
            SongEntry(title: "Song A", appleMusicID: "1"),
            SongEntry(title: "Song B", appleMusicID: "2"),
        ])
        #expect(setlist.songs.count == 2)
    }

    @Test func setlistCodableRoundTrip() throws {
        let original = Setlist(title: "Test Setlist", songs: [
            SongEntry(title: "Test Song", appleMusicID: "123", instrument: "Bass", sections: [
                Section(title: "Intro", startTime: 10, endTime: 30, role: "Lead"),
            ]),
        ])
        let data = try JSONEncoder.woodshed.encode(original)
        let decoded = try JSONDecoder.woodshed.decode(Setlist.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.songs.count == 1)
        #expect(decoded.songs[0].title == "Test Song")
        #expect(decoded.songs[0].instrument == "Bass")
        #expect(decoded.songs[0].sections.count == 1)
        #expect(decoded.songs[0].sections[0].startTime == 10)
        #expect(decoded.songs[0].sections[0].role == "Lead")
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
