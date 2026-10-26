@testable import MarkdownCore
import Testing

/// log 010 D21-01 to D21-04, as `generate.py` `saved_link` states them.
struct SavedLinkTests {
    @Test(arguments: ["", "\n \n", "just text\n"])
    func `parse finds no link in a body without a URL line`(body: String) {
        #expect(SavedLink.parse(body) == nil)
    }

    @Test
    func `parse reads a lone angle-bracket URL as a capture with host and path`() {
        #expect(SavedLink.parse("<https://www.Example.com/a/b?q=1>\n")
            == FortkeepsCard.Link(
                form: .capture,
                url: "https://www.Example.com/a/b?q=1",
                title: "example.com",
                excerpt: "/a/b"
            ))
    }

    @Test
    func `parse takes a capture title from a heading line and the excerpt from the last plain line`() {
        #expect(SavedLink.parse("# Title\nmiddle\nlast words\nhttps://e.com/\n")
            == FortkeepsCard.Link(form: .capture, url: "https://e.com/", title: "Title", excerpt: "last words"))
    }

    @Test
    func `parse does not capture after four plain lines`() {
        #expect(SavedLink.parse("a\nb\nc\nd\nhttps://e.com/x\n") == nil)
    }

    @Test
    func `parse leaves the excerpt empty for a root path`() {
        #expect(SavedLink.parse("<https://e.com/>\n")?.excerpt == nil)
    }

    @Test
    func `parse does not capture after an earlier URL line`() {
        #expect(SavedLink.parse("https://a.com/x\nhttps://b.com/y\n")
            == FortkeepsCard.Link(form: .leading, url: "https://a.com/x", title: "a.com", excerpt: "https://b.com/y"))
    }

    @Test
    func `parse does not capture after a list line`() {
        #expect(SavedLink.parse("- item\nhttps://e.com/x\n")?.form != .capture)
    }

    @Test
    func `parse reads a leading Markdown link with a title and a rendered excerpt`() {
        #expect(SavedLink.parse("[Site](https://e.com/p \"t\")\n\nSome **bold** text.\n")
            == FortkeepsCard.Link(form: .leading, url: "https://e.com/p", title: "Site", excerpt: "Some bold text."))
    }

    @Test
    func `parse uses the path as the excerpt when the leading link has no body`() {
        #expect(SavedLink.parse("https://e.com/p\n\n---\n")
            == FortkeepsCard.Link(form: .leading, url: "https://e.com/p", title: "e.com", excerpt: "/p"))
    }

    @Test
    func `parse keeps the whole URL as the host when the URL has no host`() {
        #expect(SavedLink.parse("[x](https://?q)\nmore\n")
            == FortkeepsCard.Link(form: .leading, url: "https://?q", title: "x", excerpt: "more"))
    }
}
