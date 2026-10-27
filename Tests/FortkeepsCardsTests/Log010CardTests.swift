@testable import FortkeepsCards
import Foundation
import Testing

/// remember-mac log 010 conformance cases 01-30: every `.expect.json` field
/// with the Fortkeeps value. The cases live with the MarkdownCore tree check.
struct Log010CardTests {
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("MarkdownCoreTests/Fixtures/log010")

    static let cases: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        .filter { $0.hasSuffix(".md") }
        .map { String($0.dropLast(3)) }
        .sorted()

    static func markdown(_ name: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name + ".md"), encoding: .utf8)
    }

    @Test
    func `the cases are all thirty`() {
        #expect(Self.cases.count == 30)
    }

    @Test(arguments: cases)
    func `each log 010 case matches every expect.json field with the Fortkeeps value`(name: String) throws {
        let expected = try JSONDecoder().decode(
            FortkeepsCard.self,
            from: Data(contentsOf: Self.folder.appendingPathComponent(name + ".expect.json"))
        )

        #expect(try FortkeepsCard(text: Self.markdown(name)) == expected)
    }
}
