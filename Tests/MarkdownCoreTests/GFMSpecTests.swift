import Foundation
@testable import MarkdownCore
import Testing

/// The GFM spec 0.29 examples, from swift-cmark 0.9.0 `test/spec.txt`.
struct GFMSpecTests {
    static let examples: [SpecExample] = (try? SpecExample.load()) ?? []

    /// Untagged CommonMark examples whose HTML block opens with a tag that the
    /// tag filter (on with the defaults) shows as text.
    static let tagFilterExamples: Set = [140, 141, 142, 145, 147]

    /// Untagged CommonMark examples where the autolink extension (on with the
    /// defaults) links a bare URL or email. Expected values follow the GFM
    /// autolink rules by hand. 610: the spec text allows an extended autolink only
    /// after a line start, whitespace, `*`, `_`, `~` or `(`, but cmark-gfm checks
    /// that only for `www.` (autolink.c `www_match`), not for `http://` (`url_match`).
    static let autolinkExamples: [Int: String] = [
        610: "<p>&lt;<a href=\"http://foo.bar/baz\">http://foo.bar/baz</a> bim&gt;</p>\n",
        614: "<p>&lt;<a href=\"mailto:foo+@bar.example.com\">foo+@bar.example.com</a>&gt;</p>\n",
        616: "<p>&lt; <a href=\"http://foo.bar\">http://foo.bar</a> &gt;</p>\n",
        619: "<p><a href=\"http://example.com\">http://example.com</a></p>\n",
        620: "<p><a href=\"mailto:foo@bar.example.com\">foo@bar.example.com</a></p>\n"
    ]

    static let plainExamples = examples.filter {
        !tagFilterExamples.contains($0.number) && autolinkExamples[$0.number] == nil
    }

    static func example(_ number: Int) throws -> SpecExample {
        try #require(examples.first { $0.number == number }, "no spec example \(number)")
    }

    static func render(_ example: SpecExample) -> String {
        ParsedMarkdown(example.markdown, features: MarkdownFeatures()).html()
    }

    @Test
    func `the spec fixture holds every example`() {
        #expect(Self.examples.count == 670)
        #expect(Self.plainExamples.count == 660)
    }

    @Test(arguments: plainExamples)
    func `each GFM spec example renders its HTML with the defaults`(example: SpecExample) {
        #expect(Self.render(example) == example.html)
    }

    @Test(arguments: tagFilterExamples.sorted())
    func `a CommonMark HTML block example shows its disallowed tag as text with the defaults`(number: Int) throws {
        let example = try Self.example(number)
        let filtered = example.html.replacing(/<(\/?)(script|style|textarea)/.ignoresCase()) { "&lt;\($0.1)\($0.2)" }

        #expect(Self.render(example) == filtered)
    }

    @Test(arguments: autolinkExamples.keys.sorted())
    func `a CommonMark example links its bare URL with the defaults`(number: Int) throws {
        #expect(try Self.render(Self.example(number)) == Self.autolinkExamples[number])
    }
}

struct SpecExample: Sendable, CustomTestStringConvertible {
    let number: Int
    let line: Int
    let tags: [String]
    let markdown: String
    let html: String

    var testDescription: String {
        "example \(number) (line \(line)\(tags.isEmpty ? "" : ", " + tags.joined(separator: " ")))"
    }

    static let fence = String(repeating: "`", count: 32)

    static func load() throws -> [SpecExample] {
        let spec = try String(
            contentsOf: RepoPath.url("Tests/MarkdownCoreTests/Fixtures/gfm-spec/spec.txt"),
            encoding: .utf8
        )
        var examples: [SpecExample] = []
        var lines = spec.components(separatedBy: "\n").enumerated().makeIterator()
        var number = 0
        while let (index, line) = lines.next() {
            guard line.hasPrefix(fence + " example") else { continue }
            let tags = line.dropFirst(fence.count + " example".count).split(separator: " ").map(String.init)
            var markdown: [String] = []
            var html: [String] = []
            while let (_, body) = lines.next(), body != "." {
                markdown.append(body)
            }
            while let (_, body) = lines.next(), body != fence {
                html.append(body)
            }
            number += 1
            guard !tags.contains("disabled") else { continue }
            examples.append(SpecExample(
                number: number,
                line: index + 1,
                tags: tags,
                markdown: text(markdown),
                html: text(html)
            ))
        }
        return examples
    }

    /// The spec shows a tab as U+2192; each block ends with a newline.
    private static func text(_ lines: [String]) -> String {
        lines.map { $0.replacingOccurrences(of: "\u{2192}", with: "\t") + "\n" }.joined()
    }
}
