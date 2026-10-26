import Foundation
import MarkdownCore
import Testing

/// Design › Links: the pure rules.
struct LinkRulesTests {
    static let document = URL(fileURLWithPath: "/Users/me/notes/doc.md")

    @Test(arguments: ["https://e.com/x", "HTTP://e.com", "http://e.com/a?b#c"])
    func `http and https open in the browser`(destination: String) {
        guard case .browser = LinkRules.classify(destination, documentURL: Self.document) else {
            Issue.record("\(destination) is not a browser link")
            return
        }
    }

    @Test
    func `mailto opens the mail app`() throws {
        #expect(try LinkRules.classify("mailto:a@b.co", documentURL: nil)
            == .mail(#require(URL(string: "mailto:a@b.co"))))
    }

    @Test(arguments: [
        "other.MD",
        "sub/other.markdown",
        "other.txt#part",
        "other.Mdown?x=1",
        "other.mkd",
        "my%20file.md"
    ])
    func `a sibling file with an accepted extension opens in the app`(destination: String) {
        guard case let .siblingFile(url) = LinkRules.classify(destination, documentURL: Self.document) else {
            Issue.record("\(destination) is not a sibling file")
            return
        }
        #expect(url.path.hasPrefix("/Users/me/notes/"))
        #expect(!url.path.contains("#") && !url.path.contains("?"))
    }

    @Test
    func `a sibling link drops its query and fragment and decodes its path`() {
        #expect(LinkRules.classify("my%20file.md#x", documentURL: Self.document)
            == .siblingFile(URL(fileURLWithPath: "/Users/me/notes/my file.md")))
    }

    @Test(arguments: [
        "../other.md",
        "/abs/other.md",
        "picture.png",
        "other",
        "javascript:alert(1)",
        "ftp://e.com/a.md",
        "data:text/plain,x",
        "",
        "tel:123"
    ])
    func `any other link does nothing`(destination: String) {
        #expect(LinkRules.classify(destination, documentURL: Self.document) == .none)
    }

    @Test
    func `a sibling link in an untitled document does nothing`() {
        #expect(LinkRules.classify("other.md", documentURL: nil) == .none)
    }

    @Test
    func `a fragment link names its decoded fragment`() {
        #expect(LinkRules.classify("#intro", documentURL: nil) == .fragment("intro"))
        #expect(LinkRules.classify("#caf%C3%A9", documentURL: nil) == .fragment("café"))
        #expect(LinkRules.classify("#50%zz", documentURL: nil) == .fragment("50%zz"))
    }

    // MARK: slugs

    @Test(arguments: [
        ("Intro", "intro"), ("Hello, World!", "hello-world"), ("Spaced  Out", "spaced--out"), ("a_b-c", "a_b-c"),
        ("Café Ünïcode", "café-ünïcode"), ("שלום עולם", "שלום-עולם"), ("C++ & Rust", "c--rust"), ("v1.2", "v12")
    ])
    func `a heading slug follows the GFM rule`(text: String, slug: String) {
        #expect(GFMSlug.slug(text) == slug)
    }

    @Test
    func `duplicate headings get numbered slugs`() {
        #expect(GFMSlug.slugs(["A", "A", "a", "A-1"]) == ["a", "a-1", "a-2", "a-1-1"])
    }

    @Test
    func `a fragment finds its heading block`() {
        let document = MarkdownDocument(
            text: "# Intro\n\ntext\n\n## Intro\n",
            features: MarkdownFeatures(),
            presentation: MarkdownPresentation()
        )

        #expect(document.headingBlock(forFragment: "intro")?.range == 0 ..< 5)
        #expect(document.headingBlock(forFragment: "intro-1")?.range == 11 ..< 16)
        #expect(document.headingBlock(forFragment: "missing") == nil)
    }
}
