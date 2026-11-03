import Foundation
@testable import ScrollSupport
import Testing

/// Settings (screens §3.17; log 004 Round 6).
struct ScrollSettingsTests {
    let defaults =
        UserDefaults(suiteName: "ScrollSettings-\(UUID().uuidString)")! // swiftlint:disable:this force_unwrapping

    @Test
    func `the defaults are Medium, the word count shown, and the sidebar hidden`() {
        let settings = ScrollSettings(defaults: defaults)

        #expect(settings.lineWidth == .medium)
        #expect(settings.showsWordCount)
        #expect(!settings.showsSidebar)
    }

    @Test
    func `each setting is kept`() {
        let settings = ScrollSettings(defaults: defaults)

        settings.lineWidth = .wide
        settings.showsWordCount = false
        settings.showsSidebar = true

        let again = ScrollSettings(defaults: defaults)
        #expect(again.lineWidth == .wide)
        #expect(!again.showsWordCount)
        #expect(again.showsSidebar)
    }

    @Test
    func `the line widths are 560, 680, and 840 points, with their titles`() {
        #expect(ScrollSettings.LineWidth.allCases.map(\.points) == [560, 680, 840])
        #expect(ScrollSettings.LineWidth.allCases.map(\.title) == ["Narrow", "Medium", "Wide"])
    }

    @Test
    func `the image cache button shows its size, or says it is empty`() {
        #if os(macOS)
            #expect(ScrollStrings.clearImageCache(bytes: 4_200_000) == "Clear Image Cache (4.2 MB)")
        #else
            #expect(ScrollStrings.clearImageCache(bytes: 4_200_000) == "Clear image cache (4.2 MB)")
        #endif
        #expect(ScrollStrings.clearImageCache(bytes: 0) == "Image cache is empty")
    }
}
