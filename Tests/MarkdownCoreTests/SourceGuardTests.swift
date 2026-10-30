import Foundation
import Testing

/// Design › Product: MarkdownCore and FortkeepsCards import no UI framework,
/// and no library target uses file or network I/O. scripts/check-core-modules.sh adds the
/// transitive import check (for example `import Cocoa` loads AppKit).
struct SourceGuardTests {
    @Test(arguments: ["Sources/MarkdownCore", "Sources/FortkeepsCards"])
    func `no pure-rule source imports a UI framework`(folder: String) throws {
        let hits = try SourceGuard.hits(under: folder, scan: SourceGuard.uiImports)

        #expect(hits.isEmpty, "\(hits)")
    }

    @Test(arguments: ["Sources/MarkdownCore", "Sources/FortkeepsCards", "Sources/MarkdownViews"])
    func `library sources use no file or network API`(folder: String) throws {
        let hits = try SourceGuard.hits(under: folder, scan: SourceGuard.ioUses)

        #expect(hits.isEmpty, "\(hits)")
    }

    @Test
    func `hits labels each hit with its file path`() throws {
        let hits = try SourceGuard.hits(under: "Sources/MarkdownCore") { _ in ["probe"] }

        #expect(hits.contains("DesignColors.swift: probe"))
    }

    @Test
    func `hits throws for a folder with no Swift file`() {
        #expect(throws: SourceGuard.NoFilesError.self) {
            try SourceGuard.hits(under: "Acknowledgements") { _ in [] }
        }
    }

    @Test(arguments: [
        ("import AppKit", "AppKit"),
        ("import UIKit", "UIKit"),
        ("import SwiftUI", "SwiftUI"),
        ("  @preconcurrency import AppKit", "AppKit"),
        ("@_exported public import SwiftUI", "SwiftUI"),
        ("internal import UIKit", "UIKit"),
        ("@_spi(Internal) import AppKit", "AppKit"),
        ("\timport\tSwiftUI // trailing comment", "SwiftUI"),
        ("import struct AppKit.NSColor", "AppKit"),
        ("import AppKit.NSColor", "AppKit"),
        ("import Foundation; import UIKit", "UIKit"),
        ("#if os(iOS)\nimport UIKit\n#endif", "UIKit")
    ])
    func `uiImports finds each import form`(source: String, module: String) {
        #expect(SourceGuard.uiImports(in: source) == [module])
    }

    @Test(arguments: ["import Foundation", "// import AppKit", "import AppKitExtras", "let swiftUI = 1"])
    func `uiImports ignores a line that imports no UI framework`(source: String) {
        #expect(SourceGuard.uiImports(in: source).isEmpty)
    }

    @Test(arguments: [
        ("let session = URLSession.shared", "URLSession"),
        ("FileManager.default.fileExists(atPath: path)", "FileManager"),
        ("let handle: FileHandle? = nil", "FileHandle"),
        ("let file = fopen(path, \"r\")", "fopen"),
        ("let stream = InputStream(url: url)", "InputStream"),
        ("let stream = OutputStream(url: url, append: false)", "OutputStream"),
        ("let connection = NWConnection(host: host, port: port, using: .tcp)", "NWConnection"),
        ("let data = try Data(contentsOf: url)", "contentsOf:"),
        ("let text = try String(contentsOf: url, encoding: .utf8)", "contentsOf:"),
        ("let data = try Foundation.Data(contentsOf: url)", "contentsOf:"),
        ("let data: Data = try .init(contentsOf: url)", "contentsOf:"),
        ("try data.write(to: url)", "write(to:"),
        ("try text.write(to: url, atomically: true, encoding: .utf8)", "write(to:")
    ])
    func `ioUses finds each file or network API`(source: String, name: String) {
        #expect(SourceGuard.ioUses(in: source) == [name])
    }

    @Test(arguments: [
        "lines.append(contentsOf: more)",
        "chars.insert(contentsOf: more, at: 0)",
        "value.write(to: &output)",
        "let myFileManagerName = 1"
    ])
    func `ioUses ignores code that does no I/O`(source: String) {
        #expect(SourceGuard.ioUses(in: source).isEmpty)
    }
}

enum SourceGuard {
    static let uiModules: Set<String> = ["AppKit", "UIKit", "SwiftUI"]

    /// One import statement; group 1 is its first module component.
    static let importPattern =
        #"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private)\s+)?import\s+"#
            + #"(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?(\w+)"#

    /// Each file or network API, as the label a hit reports and its pattern.
    /// `contentsOf:` outside `append`/`insert` is a URL read (`Data`, `String`,
    /// `.init`); `write(to:` without `&` is a file write, not `TextOutputStream`.
    static let ioPatterns: [(String, String)] =
        ["URLSession", "FileManager", "FileHandle", "fopen", "InputStream", "OutputStream", "NWConnection"]
            .map { ($0, #"\b\#($0)\b"#) }
            + [
                ("contentsOf:", #"(?<!append\()(?<!insert\()contentsOf:"#),
                ("write(to:", #"write\(to:(?!\s*&)"#)
            ]

    static func uiImports(in source: String) -> [String] {
        source.split(whereSeparator: { $0 == "\n" || $0 == ";" }).compactMap { statement in
            let line = String(statement)
            guard let range = line.range(of: importPattern, options: .regularExpression) else { return nil }
            let module = line[range].split(whereSeparator: { $0.isWhitespace || $0 == "." }).last.map(String.init)
            return module.flatMap { uiModules.contains($0) ? $0 : nil }
        }
    }

    static func ioUses(in source: String) -> [String] {
        ioPatterns.filter { source.range(of: $0.1, options: .regularExpression) != nil }.map(\.0)
    }

    struct NoFilesError: Error, CustomStringConvertible {
        let description: String
    }

    /// Runs `scan` on every Swift file under the repo-relative folder and
    /// labels each hit with its file name. Throws when the folder has no Swift file.
    static func hits(under relative: String, scan: (String) -> [String]) throws -> [String] {
        let root = RepoPath.url(relative)
        let files = try FileManager.default.subpathsOfDirectory(atPath: root.path).filter { $0.hasSuffix(".swift") }
        guard !files.isEmpty else { throw NoFilesError(description: "no Swift files under \(relative)") }
        return try files.sorted().flatMap { file in
            try scan(String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)).map { "\(file): \($0)" }
        }
    }
}
