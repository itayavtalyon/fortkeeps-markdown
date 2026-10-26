import Foundation
@testable import MarkdownCore
import Testing

/// remember-mac log 010 conformance cases 01-30 (copied from remember-mac
/// c673327, `design/markdown-conformance/cases`): the parse tree against each
/// `.html`, every `.expect.json` field, and the toggle test.
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

    static func markdown(_ name: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name + ".md"), encoding: .utf8)
    }

    @Test(arguments: cases)
    func `each log 010 case matches every expect.json field with the Fortkeeps value`(name: String) throws {
        let expected = try JSONDecoder().decode(
            FortkeepsCard.self,
            from: Data(contentsOf: Self.folder.appendingPathComponent(name + ".expect.json"))
        )

        #expect(try FortkeepsCard(text: Self.markdown(name)) == expected)
    }

    /// The conformance README asks for the original bytes after a second
    /// toggle. MD-29 (and design log 001 › Tasks) turns `X` into a space and a
    /// space into `x`, so `[X]` comes back as `[x]`. The test follows MD-29.
    @Test(arguments: cases)
    func `each log 010 task toggles exactly one byte and toggles back by MD-29`(name: String) throws {
        let text = try Self.markdown(name)
        for task in FortkeepsCard(text: text).tasks {
            let original = Array(text.utf8)[task.byteOffset]
            let toggled = MarkdownDocument.toggleTask(at: task.byteOffset, in: text)
            let changed = zip(Array(text.utf8), Array(toggled.utf8)).enumerated()
                .filter { $0.element.0 != $0.element.1 }
            let back = Array(MarkdownDocument.toggleTask(at: task.byteOffset, in: toggled).utf8)

            #expect(changed.map(\.offset) == [task.byteOffset], "\(name) task \(task.index)")
            #expect(back == Array(text.utf8).enumerated().map { index, byte in
                index == task.byteOffset && original == UInt8(ascii: "X") ? UInt8(ascii: "x") : byte
            }, "\(name) task \(task.index)")
        }
    }
}
