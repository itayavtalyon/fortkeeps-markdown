import Foundation
import MarkdownCore
import Testing

/// Design › Paste: 20 clipboard samples convert to fixed output.
struct PasteGoldenTests {
    static let folder = RepoPath.url("Tests/MarkdownCoreTests/Fixtures/paste")
    static let document = URL(fileURLWithPath: "/Users/me/notes/doc.md")

    static let samples: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        .filter { $0.hasSuffix(".html") }
        .map { String($0.dropLast(5)) }
        .sorted()

    @Test
    func `the golden corpus holds 20 samples`() {
        #expect(Self.samples.count == 20)
    }

    @Test(arguments: samples)
    func `each clipboard sample converts to its golden Markdown`(name: String) throws {
        let html = try String(contentsOf: Self.folder.appendingPathComponent(name + ".html"), encoding: .utf8)
        let expected = try String(contentsOf: Self.folder.appendingPathComponent(name + ".md"), encoding: .utf8)

        #expect(PasteConverter.markdown(fromHTML: html, documentURL: Self.document) == expected)
    }
}
