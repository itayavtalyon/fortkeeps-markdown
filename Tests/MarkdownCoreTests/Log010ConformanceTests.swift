import Foundation
@testable import MarkdownCore
import Testing

/// remember-mac log 010 conformance cases 01-30 (copied from remember-mac
/// c673327, `design/markdown-conformance/cases`). Stage 1b compares the parse
/// tree with each `.html`. Stage 1c adds the `.expect.json` fields.
struct Log010ConformanceTests {
    static let folder = RepoPath.url("Tests/MarkdownCoreTests/Fixtures/log010")

    static let cases: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        .filter { $0.hasSuffix(".md") }
        .map { String($0.dropLast(3)) }
        .sorted()

    @Test
    func `the fixture holds cases 01 to 30`() {
        #expect(Self.cases.map { $0.prefix(2) } == (1 ... 30).map { String(format: "%02d", $0)[...] })
    }

    @Test(arguments: cases)
    func `each log 010 case parses to the reference tree with the Fortkeeps value`(name: String) throws {
        let markdown = try String(contentsOf: Self.folder.appendingPathComponent(name + ".md"), encoding: .utf8)
        let reference = try String(contentsOf: Self.folder.appendingPathComponent(name + ".html"), encoding: .utf8)

        let html = ParsedMarkdown(markdown, features: .fortkeeps).html()

        #expect(HTMLShape.tokens(html) == HTMLShape.tokens(reference))
    }
}
