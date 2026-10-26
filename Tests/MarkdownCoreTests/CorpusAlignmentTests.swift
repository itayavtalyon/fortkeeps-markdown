import Foundation
@testable import MarkdownCore
import Testing

/// Every drawn character of the GFM spec examples and the log 010 cases maps
/// to the source bytes it came from. The only unmapped characters are breaks,
/// cell tabs, images, entities, a NUL drawn as U+FFFD, and the second scalar
/// of an entity that decodes to two scalars.
struct CorpusAlignmentTests {
    static let corpus: [(String, String)] = GFMSpecTests.examples.map { ("spec \($0.number)", $0.markdown) }
        + Log010ConformanceTests.cases.map { name in (name, (try? Log010ConformanceTests.markdown(name)) ?? "") }

    static func unmapped(_ text: String, features: MarkdownFeatures) -> [String] {
        let rendered = givenDocument(text, features: features).rendered
        let utf16 = Array(rendered.string.utf16)
        let bytes = Array(text.utf8)
        var previous: RenderedText.Run?
        var found: [String] = []
        for run in rendered.runs {
            defer { previous = run }
            guard run.text == nil else { continue }
            let character = String(decoding: utf16[run.rendered ..< run.renderedEnd], as: UTF16.self)
            let isBreak = [" ", "\n", "\t", "\u{FFFC}"].contains(character)
            let isEntityOrNul = run.source < bytes.count && [UInt8(ascii: "&"), 0].contains(bytes[run.source])
            let isEntityTail = previous
                .map { $0.text == nil && $0.sourceEnd == run.source && run.sourceLength == 0 } ?? false
            if !isBreak, !isEntityOrNul, !isEntityTail {
                found.append("\(character.debugDescription) at \(run.source)")
            }
        }
        return found
    }

    /// Found by the paste fuzz test: NUL bytes (cmark draws each as three
    /// bytes, so its later positions drift) before a code span.
    @Test
    func `a text with NUL bytes and control characters builds`() {
        let text = "\u{19}c#\u{0}![a](https://e.com/a.png)\\*a`\u{4}1K\u{0}\u{18}"
            + "[7d\u{11}=R<3&unknown;;\u{1D}<-Mc.}G `\"\\`\u{A}\u{A}\u{17}\u{301}\u{A}\u{A}"

        #expect(!givenDocument(text).rendered.string.isEmpty)
    }

    @Test
    func `the corpus holds the spec examples and the log 010 cases`() {
        #expect(Self.corpus.count == 700)
    }

    @Test
    func `every drawn character of the corpus maps to its source with the defaults`() {
        let failures = Self.corpus.flatMap { name, text in
            Self.unmapped(text, features: MarkdownFeatures()).map { "\(name): \($0)" }
        }

        #expect(failures.isEmpty, "\(failures.prefix(10))")
    }

    @Test
    func `every drawn character of the corpus maps to its source with the Fortkeeps value`() {
        let failures = Self.corpus.flatMap { name, text in
            Self.unmapped(text, features: .fortkeeps).map { "\(name): \($0)" }
        }

        #expect(failures.isEmpty, "\(failures.prefix(10))")
    }
}
