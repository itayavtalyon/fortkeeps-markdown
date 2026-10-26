import Foundation
import MarkdownCore
import Testing

/// Design › Images: the pure rules.
struct ImageRulesTests {
    static let document = URL(fileURLWithPath: "/Users/me/notes/doc.md")

    @Test(arguments: ["pic.png", "img/pic.png", "./pic.png", "img/../pic.png", "my%20pic.png", "my pic.png"])
    func `a relative path inside the document folder is local`(destination: String) {
        guard case let .local(url) = ImageRules.classify(destination, documentURL: Self.document) else {
            Issue.record("\(destination) is not local")
            return
        }
        #expect(url.path.hasPrefix("/Users/me/notes/"))
    }

    @Test
    func `a percent-encoded local path is decoded`() {
        #expect(ImageRules.classify("my%20pic.png", documentURL: Self.document)
            == .local(URL(fileURLWithPath: "/Users/me/notes/my pic.png")))
    }

    @Test(arguments: ["../pic.png", "img/../../pic.png", "%2E%2E/pic.png", "/etc/pic.png", "bad%zzpath.png"])
    func `a path that leaves the document folder or is not a plain relative path is refused`(destination: String) {
        #expect(ImageRules.classify(destination, documentURL: Self.document) == .refused)
    }

    @Test
    func `an untitled document refuses a local path`() {
        #expect(ImageRules.classify("pic.png", documentURL: nil) == .refused)
    }

    @Test
    func `https is remote`() throws {
        #expect(try ImageRules.classify("https://example.com/a.png", documentURL: nil)
            ==
            .remote(
                #require(URL(string: "https://example.com/a.png"))
            ))
    }

    @Test(arguments: [
        "http://example.com/a.png",
        "data:image/png;base64,AAAA",
        "file:///etc/a.png",
        "ftp://e.com/a.png",
        "//example.com/a.png",
        "javascript:alert(1)"
    ])
    func `any other scheme is refused`(destination: String) {
        #expect(ImageRules.classify(destination, documentURL: Self.document) == .refused)
    }

    @Test(arguments: [
        "localhost", "LOCALHOST", "localhost.", "printer.local", "printer.local.",
        "0.0.0.1", "10.1.2.3", "100.64.0.1", "100.127.255.255", "127.0.0.1", "169.254.1.1", "172.16.0.1",
        "172.31.255.255",
        "192.168.1.1", "198.18.0.1", "198.19.255.255", "224.0.0.1", "239.255.255.255", "240.0.0.1", "255.255.255.255",
        "::", "::1", "[::1]", "fc00::1", "fdff::1", "fe80::1", "febf::1", "::ffff:127.0.0.1", "::ffff:7f00:1",
        "fe80::1%en0",
        "2130706433", "0x7f.1", "0177.0.0.1", "127.1", "0x7f000001", "017700000001", "127.0.0.01", "1:2:3"
    ])
    func `each blocklist form is refused`(host: String) {
        #expect(ImageRules.isBlockedHost(host))
        #expect(ImageRules.classify("https://\(host)/a.png", documentURL: nil) == .refused)
    }

    @Test(arguments: [
        "example.com",
        "8.8.8.8",
        "100.128.0.1",
        "172.32.0.1",
        "198.20.0.1",
        "223.255.255.255",
        "2001:db8::1",
        "::ffff:8.8.8.8",
        "local.example.com",
        "1.example.com"
    ])
    func `a public host is allowed`(host: String) {
        #expect(!ImageRules.isBlockedHost(host))
    }
}
