import CryptoKit
import Foundation
import os

/// The remote images on disk (design log 001 › Images). A file is named by
/// the SHA-256 of its URL, is excluded from backup, and its modification
/// date is its last view. An entry expires 3 days after its last view.
struct ImageCache {
    static let lifetime: TimeInterval = 3 * 86400

    let directory: URL
    var now: @Sendable () -> Date = Date.init

    /// The app's cache: Caches/Images.
    static var standard: ImageCache {
        ImageCache(directory: URL.cachesDirectory.appending(path: "Images"))
    }

    /// The image of `url`, or nil when it is missing or expired. A read is a view.
    func image(for url: URL) -> Data? {
        let file = file(url)
        guard isFresh(file), let data = try? Data(contentsOf: file) else { return nil }
        touch(file)
        return data
    }

    /// A failed write leaves the entry out and is logged; the image still shows.
    func store(_ data: Data, for url: URL) {
        var file = file(url)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try file.setResourceValues(values)
        } catch {
            Logger(subsystem: "app.fortkeeps.scroll", category: "ImageCache")
                .error("cache write failed: \(error, privacy: .public)")
            try? FileManager.default.removeItem(at: file)
            return
        }
        touch(file)
    }

    /// Removes the expired entries.
    func purge() {
        for file in files() where !isFresh(file) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func clear() {
        for file in files() {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// The bytes on disk.
    func size() -> Int {
        files().compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }.reduce(0, +)
    }

    private func file(_ url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return directory.appending(path: digest.map { String(format: "%02x", $0) }.joined())
    }

    private func files() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    /// True while the file exists and its last view is at most 3 days ago.
    private func isFresh(_ file: URL) -> Bool {
        guard let viewed = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return false }
        return now().timeIntervalSince(viewed) <= Self.lifetime
    }

    private func touch(_ file: URL) {
        try? FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: file.path)
    }
}
