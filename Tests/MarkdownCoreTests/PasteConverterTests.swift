import Foundation
import MarkdownCore
import Testing

/// Design › Paste: one test per row of the HTML-to-Markdown table.
struct PasteConverterTests {
    static let document = URL(fileURLWithPath: "/Users/me/notes/doc.md")

    static func markdown(_ html: String) -> String {
        PasteConverter.markdown(fromHTML: html, documentURL: document)
    }

    @Test(arguments: 1 ... 6)
    func `a heading becomes an ATX heading of its level`(level: Int) {
        #expect(Self
            .markdown("<h\(level)>Title <em>x</em></h\(level)>") == String(repeating: "#", count: level) + " Title *x*")
    }

    @Test
    func `p and div become paragraphs`() {
        #expect(Self.markdown("<p>one</p><div>two</div><p>three</p>") == "one\n\ntwo\n\nthree")
    }

    @Test
    func `br becomes a line break`() {
        #expect(Self.markdown("<p>a<br>b</p>") == "a\\\nb")
    }

    @Test
    func `br inside a table cell becomes a space`() {
        #expect(Self.markdown("<table><tr><td>a<br>b</td></tr></table>") == "| a b |\n| --- |")
    }

    @Test(arguments: ["strong", "b"])
    func `strong and b become double asterisks`(tag: String) {
        #expect(Self.markdown("<p>a <\(tag)>bold</\(tag)> c</p>") == "a **bold** c")
    }

    @Test(arguments: ["em", "i"])
    func `em and i become one asterisk`(tag: String) {
        #expect(Self.markdown("<p>a <\(tag)>it</\(tag)> c</p>") == "a *it* c")
    }

    @Test(arguments: ["del", "s", "strike"])
    func `del, s, and strike become double tildes`(tag: String) {
        #expect(Self.markdown("<p><\(tag)>old</\(tag)></p>") == "~~old~~")
    }

    @Test
    func `spaces at the edge of an emphasis move outside it`() {
        #expect(Self.markdown("<p>a<b> bold </b>c</p>") == "a **bold** c")
    }

    @Test
    func `pre becomes a fenced code block`() {
        #expect(Self.markdown("<pre><code>let a = 1\n  *b*\n</code></pre>") == "```\nlet a = 1\n  *b*\n```")
    }

    @Test
    func `a fence is longer than any backtick run in the code`() {
        #expect(Self.markdown("<pre>a ``` b</pre>") == "````\na ``` b\n````")
    }

    @Test
    func `a code element that holds lines becomes a fenced code block`() {
        #expect(Self.markdown("<div><code>a\nb</code></div>") == "```\na\nb\n```")
    }

    @Test
    func `inline code becomes a code span`() {
        #expect(Self.markdown("<p>run <code>ls -a</code> and <code>a`b</code></p>") == "run `ls -a` and ``a`b``")
    }

    @Test(arguments: ["https://e.com/x", "mailto:a@b.co"])
    func `a link with an https or mailto href keeps its destination`(href: String) {
        #expect(Self.markdown("<p><a href=\"\(href)\">go <b>there</b></a></p>") == "[go **there**](\(href))")
    }

    @Test(arguments: ["http://e.com", "javascript:alert(1)", "/relative", "#frag", ""])
    func `any other link keeps its text only`(href: String) {
        #expect(Self.markdown("<p><a href=\"\(href)\">text</a></p>") == "text")
    }

    @Test
    func `a destination with spaces or parentheses is wrapped in angle brackets`() {
        #expect(Self.markdown("<a href=\"https://e.com/a b(c)\">x</a>") == "[x](<https://e.com/a b(c)>)")
    }

    @Test
    func `a bullet list nests with two spaces`() {
        #expect(Self.markdown("<ul><li>a<ul><li>b</li></ul></li><li>c</li></ul>") == "- a\n  - b\n- c")
    }

    @Test
    func `an ordered list nests with three spaces and keeps its start`() {
        #expect(Self.markdown("<ol start=\"4\"><li>a<ol><li>b</li></ol></li><li>c</li></ol>") == "4. a\n   1. b\n5. c")
    }

    @Test
    func `blockquote becomes a quote`() {
        #expect(Self.markdown("<blockquote><p>a</p><p>b</p></blockquote>") == "> a\n>\n> b")
    }

    @Test
    func `a table without thead takes its first row as the header`() {
        #expect(Self.markdown("<table><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></table>")
            == "| a | b |\n| --- | --- |\n| c | d |")
    }

    @Test
    func `a table with thead uses it as the header`() {
        #expect(Self.markdown("<table><thead><tr><th>h</th></tr></thead><tbody><tr><td>x</td></tr></tbody></table>")
            == "| h |\n| --- |\n| x |")
    }

    @Test
    func `a thead after the body rows is still the header`() {
        #expect(Self.markdown("<table><tbody><tr><td>x</td></tr></tbody><thead><tr><th>h</th></tr></thead></table>")
            == "| h |\n| --- |\n| x |")
    }

    @Test
    func `a colspan cell puts its content in the first cell and empty cells after it`() {
        #expect(Self
            .markdown(
                "<table><tr><th>a</th><th>b</th><th>c</th></tr><tr><td colspan=\"2\">wide</td><td>z</td></tr></table>"
            )
            == "| a | b | c |\n| --- | --- | --- |\n| wide |  | z |")
    }

    @Test
    func `a pipe in a table cell is escaped`() {
        #expect(Self.markdown("<table><tr><td>a|b</td></tr></table>") == "| a\\|b |\n| --- |")
    }

    @Test
    func `an image that the image rules allow keeps its source`() {
        #expect(Self.markdown("<p><img src=\"https://e.com/a.png\" alt=\"pic\"></p>") == "![pic](https://e.com/a.png)")
        #expect(Self.markdown("<p><img src=\"img/a.png\" alt=\"local\"></p>") == "![local](img/a.png)")
        #expect(Self.markdown("<p><img src=\"https://e.com/a.png\"></p>") == "![](https://e.com/a.png)")
    }

    @Test(arguments: ["http://e.com/a.png", "data:image/png;base64,AA", "https://127.0.0.1/a.png", "../a.png"])
    func `any other image becomes its alt text`(source: String) {
        #expect(Self.markdown("<p><img src=\"\(source)\" alt=\"pic\"></p>") == "pic")
    }

    @Test
    func `a checkbox input becomes a task item`() {
        #expect(Self
            .markdown("<ul><li><input type=\"checkbox\" checked> done</li><li><input type=\"checkbox\"> todo</li></ul>")
            == "- [x] done\n- [ ] todo")
    }

    @Test
    func `any other element keeps its children without its tag`() {
        #expect(Self
            .markdown("<section><span class=\"x\" style=\"color:red\">a <font>b</font></span></section>") == "a b")
    }

    // MARK: dropped content

    @Test
    func `a script body does not appear`() {
        #expect(Self.markdown("<p>a</p><script>alert('x <b>y</b>')</script><p>b</p>") == "a\n\nb")
    }

    @Test
    func `a style element and its text are dropped`() {
        #expect(Self.markdown("<style>p { color: red }</style><p>a</p>") == "a")
    }

    @Test
    func `comments and doctype are dropped`() {
        #expect(Self.markdown("<!DOCTYPE html><!-- c --><p>a<!-- d -->b</p>") == "ab")
    }

    // MARK: whitespace and escaping

    @Test
    func `whitespace collapses as in HTML`() {
        #expect(Self.markdown("<p>  a \n\t b  </p>\n\n<p> c</p>") == "a b\n\nc")
    }

    @Test
    func `entities are decoded`() {
        #expect(Self.markdown("<p>&lt;tag&gt; &amp; &copy; &#x263A; &nbsp;x</p>") == "\\<tag> & © ☺ \u{A0}x")
    }

    @Test(arguments: [
        ("2*3 and a * b", "2\\*3 and a * b"),
        ("snake_case and _x_", "snake_case and \\_x\\_"),
        ("# not a heading", "\\# not a heading"),
        ("#hashtag", "#hashtag"),
        ("- not a list", "\\- not a list"),
        ("well - fine", "well - fine"),
        ("1. not a list", "1\\. not a list"),
        ("1.5 is fine", "1.5 is fine"),
        ("> not a quote", "\\> not a quote"),
        ("a > b", "a > b"),
        ("see [x]", "see \\[x]"),
        ("`tick`", "\\`tick\\`"),
        ("a <b> c", "a \\<b> c"),
        ("a < b", "a < b"),
        ("AT&T &amp;", "AT&T \\&amp;"),
        ("~~x~~ and a ~ b", "\\~\\~x\\~\\~ and a ~ b"),
        ("back\\slash \\* x", "back\\slash \\\\\\* x"),
        ("===", "\\==="),
        ("plain words", "plain words")
    ])
    func `escaping happens only where a character would start syntax`(text: String, escaped: String) {
        let html = "<p>" + text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(
            of: "<",
            with: "&lt;"
        ) + "</p>"

        #expect(Self.markdown(html) == escaped)
    }

    @Test(arguments: [
        "2*3 and a * b", "snake_case and _x_", "# h", "- l", "1. o", "> q", "see [x](y)", "`t`", "<b>", "AT&T &amp;",
        "~~x~~", "back\\slash \\* x", "===", "---", "***", "+ x", "1) y", "![a](b)", "<https://e.com>", "a\\b"
    ])
    func `escaped text renders as the original text`(text: String) {
        let html = "<p>" + text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(
            of: "<",
            with: "&lt;"
        ) + "</p>"
        let markdown = Self.markdown(html)
        var features = MarkdownFeatures()
        features.autolink = false
        let rendered = MarkdownDocument(text: markdown, features: features, presentation: MarkdownPresentation())
            .rendered

        #expect(rendered.string == text, "\(markdown)")
    }

    // MARK: paste text

    @Test
    func `pasteText converts HTML when pasteHtml is on`() {
        #expect(PasteConverter.pasteText(
            html: "<b>Hi</b>",
            plainText: "Hi",
            features: MarkdownFeatures(),
            documentURL: nil
        )
            == "**Hi**")
    }

    @Test
    func `pasteText inserts the plain text when pasteHtml is off`() {
        #expect(PasteConverter
            .pasteText(html: "<b>Hi</b>", plainText: "Hi", features: .fortkeeps, documentURL: nil) == "Hi")
    }

    @Test
    func `pasteText inserts the plain text when there is no HTML`() {
        #expect(PasteConverter
            .pasteText(html: nil, plainText: "Hi", features: MarkdownFeatures(), documentURL: nil) == "Hi")
    }

    @Test
    func `pasteText inserts the plain text when the conversion is whitespace only`() {
        #expect(PasteConverter.pasteText(
            html: "<script>x</script> <p> </p>",
            plainText: "x",
            features: MarkdownFeatures(),
            documentURL: nil
        ) == "x")
    }
}
