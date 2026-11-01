import Foundation
@testable import ScrollSupport
import Synchronization
import Testing

/// Design › Images: the image cache in Caches/Images.
struct ImageCacheTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "ImageCacheTests-\(UUID().uuidString)")
    let clock = FakeClock()
    let url = URL(string: "https://e.com/a.png")!

    var cache: ImageCache {
        ImageCache(directory: directory, now: clock.now)
    }

    @Test
    func `a stored image is read back, also by a new cache on the same folder`() throws {
        cache.store(Data("png".utf8), for: url)

        #expect(cache.image(for: url) == Data("png".utf8))
        #expect(ImageCache(directory: directory, now: clock.now).image(for: url) == Data("png".utf8))
        #expect(try cache.image(for: #require(URL(string: "https://e.com/b.png"))) == nil)
    }

    @Test
    func `the file name is the SHA-256 of the URL`() throws {
        cache.store(Data("png".utf8), for: url)

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(names == ["aedd466ca38a177c039c13df2b5e38052b446b7dfb4404e3e41ad31537316c9a"])
    }

    @Test
    func `every cached file is excluded from backup`() throws {
        cache.store(Data("png".utf8), for: url)

        let file = directory.appending(path: "aedd466ca38a177c039c13df2b5e38052b446b7dfb4404e3e41ad31537316c9a")
        #expect(try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test
    func `an entry expires 3 days after its last view`() {
        cache.store(Data("png".utf8), for: url)
        clock.advance(by: 3 * 86400 - 1)
        #expect(cache.image(for: url) != nil)

        clock.advance(by: 3 * 86400 - 1)
        #expect(cache.image(for: url) != nil, "the view above moved the expiry")

        clock.advance(by: 3 * 86400 + 1)
        #expect(cache.image(for: url) == nil)
    }

    @Test
    func `an entry is still shown exactly 3 days after its last view`() {
        cache.store(Data("png".utf8), for: url)
        clock.advance(by: 3 * 86400)

        #expect(cache.image(for: url) != nil)
    }

    @Test
    func `a failed write stores nothing and the cache stays usable`() throws {
        try FileManager.default.createDirectory(
            at: directory.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        cache.store(Data("png".utf8), for: url)

        #expect(cache.image(for: url) == nil)
        #expect(cache.size() == 0)
    }

    @Test
    func `the app cache is Caches/Images and reads the system clock`() {
        let standard = ImageCache.standard
        #expect(standard.directory == URL.cachesDirectory.appending(path: "Images"))
        #expect(abs(standard.now().timeIntervalSinceNow) < 60)
    }

    @Test
    func `purge removes only expired entries`() throws {
        let other = try #require(URL(string: "https://e.com/b.png"))
        cache.store(Data("old".utf8), for: url)
        clock.advance(by: 2 * 86400)
        cache.store(Data("new".utf8), for: other)
        clock.advance(by: 86400 + 1)

        cache.purge()

        #expect(cache.size() == 3)
        #expect(cache.image(for: other) == Data("new".utf8))
    }

    @Test
    func `clear empties the cache and size counts the bytes`() throws {
        cache.store(Data("png".utf8), for: url)
        try cache.store(Data("jpeg".utf8), for: #require(URL(string: "https://e.com/b.jpg")))
        #expect(cache.size() == 7)

        cache.clear()

        #expect(cache.size() == 0)
        #expect(cache.image(for: url) == nil)
    }

    @Test
    func `an empty or missing folder has size 0 and purges without error`() {
        #expect(cache.size() == 0)
        cache.purge()
        cache.clear()
        #expect(cache.size() == 0)
    }
}

/// A clock the test moves by hand.
final class FakeClock: Sendable {
    private let date = Mutex(Date(timeIntervalSinceReferenceDate: 800_000_000))

    var now: @Sendable () -> Date {
        { [self] in date.withLock { $0 } }
    }

    func advance(by seconds: TimeInterval) {
        date.withLock { $0 += seconds }
    }
}
