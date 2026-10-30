import CryptoKit
import Foundation
@testable import MarkdownViews
import Testing

/// design/fonts/README.md is the record. Both copies (design/fonts/ and the
/// shipped MarkdownViews bundle) must match it byte for byte.
struct FontRecordTests {
    static let sha = String(repeating: "a1", count: 32)

    @Test
    func `parse reads the file and SHA-256 cells of each table row`() throws {
        let readme = "# Fonts\n\n| File | Tag | SHA-256 |\n|---|---|---|\n| `A.ttf` | `t` | `\(Self.sha)` |\n- note\n"

        #expect(try FontRecord.parse(readme) == ["A.ttf": Self.sha])
    }

    @Test(arguments: [String(repeating: "a", count: 63), String(repeating: "g", count: 64)])
    func `parse rejects a SHA-256 cell that is not 64 hex digits`(sha: String) {
        #expect(throws: FontRecord.ParseError.self) {
            try FontRecord.parse("| `A.ttf` | `t` | `\(sha)` |\n")
        }
    }

    @Test
    func `parse rejects a file recorded twice`() {
        #expect(throws: FontRecord.ParseError.self) {
            try FontRecord.parse("| `A.ttf` | `t` | `\(Self.sha)` |\n| `A.ttf` | `u` | `\(Self.sha)` |\n")
        }
    }
}

struct FontFilesTests {
    static let designFolder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("design/fonts")

    enum Copy: CaseIterable {
        case design, bundled

        func folder() throws -> URL {
            switch self {
            case .design: FontFilesTests.designFolder
            case .bundled: try #require(resourceBundle.url(forResource: "Fonts", withExtension: nil))
            }
        }
    }

    static let shippedFiles = [
        "IBMPlexMono-Medium.ttf", "IBMPlexMono-Regular.ttf", "IBMPlexMono-SemiBold.ttf",
        "IBMPlexSans-Italic.ttf", "IBMPlexSans-Medium.ttf", "IBMPlexSans-Regular.ttf",
        "IBMPlexSans-SemiBold.ttf", "OFL.txt"
    ]

    @Test
    func `the fonts README records the seven Plex files and OFL.txt`() throws {
        #expect(try FontRecord.load(from: Self.designFolder).keys.sorted() == Self.shippedFiles)
    }

    @Test(arguments: Copy.allCases)
    func `each font folder holds exactly the recorded files`(copy: Copy) throws {
        let record = try FontRecord.load(from: Self.designFolder)

        #expect(try FontRecord.payloadFiles(in: copy.folder()) == record.keys.sorted())
    }

    @Test(arguments: Copy.allCases, shippedFiles)
    func `each font file matches its recorded SHA-256`(copy: Copy, name: String) throws {
        let recorded = try #require(try FontRecord.load(from: Self.designFolder)[name], "\(name) not in README")

        #expect(try FontRecord.sha256(copy.folder().appendingPathComponent(name)) == recorded)
    }
}

/// Reads the `| `file` | tag | sha256 |` rows of design/fonts/README.md.
enum FontRecord {
    struct ParseError: Error, CustomStringConvertible {
        let description: String
    }

    static func load(from folder: URL) throws -> [String: String] {
        try parse(String(contentsOf: folder.appendingPathComponent("README.md"), encoding: .utf8))
    }

    static func parse(_ readme: String) throws -> [String: String] {
        var rows: [String: String] = [:]
        for line in readme.split(separator: "\n") {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count == 3, cells[0].hasPrefix("`") else { continue }
            let name = cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            let sha = cells[2].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            guard sha.count == 64, sha.allSatisfy(\.isHexDigit), rows[name] == nil else {
                throw ParseError(description: "bad README row: \(line)")
            }
            rows[name] = sha
        }
        return rows
    }

    /// Every file in the folder except README.md, sorted.
    static func payloadFiles(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0 != "README.md" && $0 != ".DS_Store" }
            .sorted()
    }

    static func sha256(_ file: URL) throws -> String {
        try SHA256.hash(data: Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
    }
}
