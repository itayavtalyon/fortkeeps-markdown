import Testing

struct HTMLShapeTests {
    @Test
    func `tokens keep element names and drop other attributes`() {
        #expect(HTMLShape.tokens(#"<ul class="x"><li style="y">a</li></ul>"#) == ["ul", "li", "text:a", "/li", "/ul"])
    }

    @Test
    func `tokens keep href on a link`() {
        #expect(HTMLShape.tokens(#"<a title="t" href="https://e.com/?a=1&amp;b=2">x</a>"#)
            == ["a href=https://e.com/?a=1&b=2", "text:x", "/a"])
    }

    @Test(arguments: [
        (#"<input type="checkbox" checked="" disabled="" />"#, "input checked"),
        (#"<input class="c" checked="checked"  type="checkbox">"#, "input checked"),
        (#"<input type="checkbox" disabled="" />"#, "input")
    ])
    func `tokens keep the checked state of an input`(html: String, token: String) {
        #expect(HTMLShape.tokens(html) == [token])
    }

    @Test
    func `tokens draw an image as its Image link`() {
        #expect(HTMLShape.tokens(#"<img src="d.png" alt="diagram" />"#) == [
            "a href=d.png",
            "text:Image: diagram",
            "/a"
        ])
    }

    @Test
    func `tokens treat a void tag with or without a slash the same`() {
        #expect(HTMLShape.tokens("a<br />\nb") == HTMLShape.tokens("a<br>\nb"))
    }

    @Test
    func `tokens collapse whitespace runs and merge text split by entities`() {
        #expect(HTMLShape.tokens("<p>  a \n\t b &amp;\n c </p>") == ["p", "text:a b & c", "/p"])
    }

    @Test(arguments: [
        ("&lt;&gt;&amp;&quot;&apos;", "<>&\"'"),
        ("&#65;&#x42;&#X43;", "ABC"),
        ("&bogus; &#xZZ;", "&bogus; &#xZZ;")
    ])
    func `decode resolves named, decimal, and hex entities and keeps unknown ones`(text: String, decoded: String) {
        #expect(HTMLShape.decode(text) == decoded)
    }
}
