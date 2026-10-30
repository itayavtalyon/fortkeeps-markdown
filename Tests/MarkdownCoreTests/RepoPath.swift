import Foundation

/// The repository root, found from this file's compile-time path, so repo
/// checks read the real files in the checkout.
enum RepoPath {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    static func url(_ relative: String) -> URL {
        root.appendingPathComponent(relative)
    }
}
