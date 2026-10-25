@testable import MarkdownCore
import Testing

/// Design › Parse and Features. The HTML is cmark-gfm's own renderer, so each
/// expectation is the GFM reference output for that input.
struct ParsedMarkdownTests {
    static func html(_ text: String, _ change: (inout MarkdownFeatures) -> Void = { _ in }) -> String {
        var features = MarkdownFeatures()
        change(&features)
        return ParsedMarkdown(text, features: features).html()
    }

    // MARK: defaults

    @Test
    func `defaults render a table`() {
        #expect(Self.html("| a |\n|---|\n| b |\n") == """
        <table>
        <thead>
        <tr>
        <th>a</th>
        </tr>
        </thead>
        <tbody>
        <tr>
        <td>b</td>
        </tr>
        </tbody>
        </table>

        """)
    }

    @Test
    func `defaults render a task`() {
        #expect(Self
            .html("- [x] done\n") ==
            "<ul>\n<li><input type=\"checkbox\" checked=\"\" disabled=\"\" /> done</li>\n</ul>\n")
    }

    @Test
    func `defaults render a strikethrough`() {
        #expect(Self.html("~~old~~\n") == "<p><del>old</del></p>\n")
    }

    @Test
    func `defaults render a bare URL as a link`() {
        #expect(Self
            .html("see www.example.com now\n") ==
            "<p>see <a href=\"http://www.example.com\">www.example.com</a> now</p>\n")
    }

    @Test
    func `defaults render a soft break as a newline`() {
        #expect(Self.html("a\nb\n") == "<p>a\nb</p>\n")
    }

    @Test
    func `defaults keep raw HTML`() {
        #expect(Self.html("<b>hi</b>\n") == "<p><b>hi</b></p>\n")
    }

    @Test(arguments: ["title", "textarea", "style", "xmp", "iframe", "noembed", "noframes", "script", "plaintext"])
    func `defaults show a disallowed tag as text`(tag: String) {
        #expect(Self.html("x <\(tag)> y\n") == "<p>x &lt;\(tag)> y</p>\n")
    }

    @Test
    func `defaults keep an allowed tag next to a disallowed one`() {
        #expect(Self.html("x <em> <TEXTAREA> y\n") == "<p>x <em> &lt;TEXTAREA> y</p>\n")
    }

    @Test
    func `a leading thematic break line stays a thematic break`() {
        #expect(Self.html("---\ntitle: x\n") == "<hr />\n<p>title: x</p>\n")
    }

    // MARK: each false field

    @Test
    func `tables false leaves a pipe table as a paragraph`() {
        #expect(Self.html("| a |\n|---|\n| b |\n") { $0.tables = false } == "<p>| a |\n|---|\n| b |</p>\n")
    }

    @Test
    func `taskLists false leaves a task as a plain list item`() {
        #expect(Self.html("- [x] done\n") { $0.taskLists = false } == "<ul>\n<li>[x] done</li>\n</ul>\n")
    }

    @Test
    func `strikethrough false leaves tildes as text`() {
        #expect(Self.html("~~old~~\n") { $0.strikethrough = false } == "<p>~~old~~</p>\n")
    }

    @Test
    func `autolink false leaves a bare URL as text`() {
        #expect(Self.html("see www.example.com now\n") { $0.autolink = false } == "<p>see www.example.com now</p>\n")
    }

    @Test
    func `autolink false keeps an angle-bracket autolink`() {
        #expect(Self.html("<a@b.co>\n") { $0.autolink = false } == "<p><a href=\"mailto:a@b.co\">a@b.co</a></p>\n")
    }

    @Test
    func `html false shows inline HTML as text`() {
        #expect(Self.html("a <b>hi</b>\n") { $0.html = false } == "<p>a &lt;b&gt;hi&lt;/b&gt;</p>\n")
    }

    @Test
    func `html false turns an HTML block into a paragraph`() {
        #expect(Self.html("<div class=\"x\">\nblock html\n</div>\n") { $0.html = false }
            == "<p>&lt;div class=&quot;x&quot;&gt;\nblock html\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false parses inline syntax inside a former HTML block`() {
        #expect(Self.html("<div>\n*em* <a@b.co>\n</div>\n") { $0.html = false }
            == "<p>&lt;div&gt;\n<em>em</em> <a href=\"mailto:a@b.co\">a@b.co</a>\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false keeps a former HTML block inside its quote`() {
        #expect(Self
            .html("> <div>\n> x\n") { $0.html = false } == "<blockquote>\n<p>&lt;div&gt;\nx</p>\n</blockquote>\n")
    }

    @Test
    func `html false gives a former HTML block line breaks with softBreakAsLine`() {
        let html = Self.html("<div>\na\n</div>\n") {
            $0.html = false
            $0.softBreakAsLine = true
        }

        #expect(html == "<p>&lt;div&gt;<br />\na<br />\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false turns a three-space-indented HTML block into a paragraph`() {
        #expect(Self.html("   <div>\nx\n   </div>\n") { $0.html = false } == "<p>&lt;div&gt;\nx\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false parses a heading line inside a former HTML block`() {
        #expect(Self.html("<div>\n# h\n</div>\n") { $0.html = false }
            == "<p>&lt;div&gt;</p>\n<h1>h</h1>\n<p>&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false splits a former HTML block at a blank line`() {
        #expect(Self.html("<script>\na\n\nb\n</script>\n") { $0.html = false }
            == "<p>&lt;script&gt;\na</p>\n<p>b\n&lt;/script&gt;</p>\n")
    }

    @Test
    func `html false keeps an autolink that starts a line of a former HTML block`() {
        #expect(Self.html("<div>\n<a@b.co>\n</div>\n") { $0.html = false }
            == "<p>&lt;div&gt;\n<a href=\"mailto:a@b.co\">a@b.co</a>\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false restores a neutralized bracket inside a code span`() {
        #expect(Self.html("<div> `a\n<div> b`\n") { $0.html = false }
            == "<p>&lt;div&gt; <code>a &lt;div&gt; b</code></p>\n")
    }

    @Test
    func `html false keeps a control character that was already in an HTML block`() {
        #expect(Self.html("<div>\u{1}\n</div>\n") { $0.html = false } == "<p>&lt;div&gt;\u{1}\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false never uses a tab as the stand-in for a bracket`() {
        let low = (1 ... 8).map { String(Character(Unicode.Scalar(UInt8($0)))) }.joined()

        #expect(Self.html("<div>\(low)\n</div>\n") { $0.html = false } == "<p>&lt;div&gt;\(low)\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false converts every HTML block`() {
        #expect(Self.html("<div>\na\n</div>\n\n<p>\nb\n</p>\n") { $0.html = false }
            == "<p>&lt;div&gt;\na\n&lt;/div&gt;</p>\n<p>&lt;p&gt;\nb\n&lt;/p&gt;</p>\n")
    }

    @Test
    func `html false neutralizes an HTML block whose text holds every spare control character`() {
        let controls = String(ParsedMarkdown.sentinels.map(Character.init))

        #expect(Self.html("<div>\(controls)\n</div>\n") { $0.html = false }
            == "<p>&lt;div&gt;\(controls)\n&lt;/div&gt;</p>\n")
    }

    @Test
    func `html false shows a disallowed tag as text`() {
        #expect(Self
            .html("<script>alert(1)</script>\n") { $0.html = false } ==
            "<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>\n")
    }

    @Test
    func `softBreakAsLine true renders a soft break as a line break`() {
        #expect(Self.html("a\nb\n") { $0.softBreakAsLine = true } == "<p>a<br />\nb</p>\n")
    }
}
