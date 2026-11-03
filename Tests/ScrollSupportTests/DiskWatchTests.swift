import Foundation
@testable import ScrollSupport
import Testing

/// Design log 004 › Outside changes, Round 7: what another app's bytes mean.
struct DiskWatchTests {
    @Test
    func `other text is a change, and the bytes are kept as the last read`() {
        var watch = DiskWatch()

        #expect(watch.change(to: Data("b\n".utf8), text: "a\n") == .text("b\n"))
        #expect(watch.data == Data("b\n".utf8))
    }

    @Test
    func `the same text in other bytes is no change`() {
        var watch = DiskWatch()

        #expect(watch.change(to: Data("a\r\n".utf8), text: "a\n") == nil)
        #expect(watch.data == Data("a\r\n".utf8))
    }

    @Test(arguments: [Data([0x61, 0xFF]), Data([0x61, 0x00, 0x0A])])
    func `bytes that are not UTF-8 text are unreadable`(bytes: Data) {
        var watch = DiskWatch()

        #expect(watch.change(to: bytes, text: "a\n") == .unreadable)
        #expect(watch.data == bytes)
    }

    @Test
    func `a move into a Trash is a deletion`() {
        #expect(DiskWatch.isTrash(URL(filePath: "/Users/me/.Trash/a.md")))
        #expect(!DiskWatch.isTrash(URL(filePath: "/Users/me/Notes/a.md")))
    }
}
