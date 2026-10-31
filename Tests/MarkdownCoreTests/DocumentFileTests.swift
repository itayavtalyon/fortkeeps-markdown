import Foundation
import MarkdownCore
import Testing

/// Design › Files: the pure open and save rules.
struct DocumentFileTests {
    @Test(arguments: ["md", "markdown", "txt", "mdown", "mkd", "MD", "MARKDOWN", "TXT", "MDOWN", "MKD", "Md"])
    func `each accepted extension and its uppercase form are accepted`(pathExtension: String) {
        #expect(DocumentFile.accepts(URL(fileURLWithPath: "/notes/a.\(pathExtension)")))
    }

    @Test(arguments: [
        "/notes/a.rtf",
        "/notes/a.md.zip",
        "/notes/a",
        "/notes/md",
        "/notes/.md",
        "/notes/a.mdx",
        "/notes/a.m d"
    ])
    func `any other extension is refused`(path: String) {
        #expect(!DocumentFile.accepts(URL(fileURLWithPath: path)))
    }

    @Test(arguments: [
        [0xC3, 0x28],
        [0xFF],
        [0x61, 0xE2, 0x82],
        [0xC0, 0xAF],
        [0xED, 0xA0, 0x80],
        [0xF4, 0x90, 0x80, 0x80]
    ] as [[UInt8]])
    func `invalid UTF-8 is refused and gives no text`(bytes: [UInt8]) {
        #expect(throws: DocumentFile.Refusal.notUTF8) { try DocumentFile.text(from: Data(bytes)) }
    }

    @Test(arguments: ["\0", "a\0b", "# a\n\0", "\u{FEFF}\0"])
    func `a NUL byte is refused and gives no text`(text: String) {
        #expect(throws: DocumentFile.Refusal.notUTF8) { try DocumentFile.text(from: Data(text.utf8)) }
    }

    @Test(arguments: [
        ("a\r\nb\r\n", "a\nb\n"),
        ("a\rb\r", "a\nb\n"),
        ("a\r\nb\rc\n\r\r\nd\n", "a\nb\nc\n\n\nd\n"),
        ("\r\n", "\n"),
        ("\r", "\n"),
        ("a\r\n\nb\n", "a\n\nb\n"),
        ("a\r\r\n\r\nb\n", "a\n\n\nb\n")
    ])
    func `CRLF, a lone CR, and mixed endings become LF in the buffer`(file: String, buffer: String) throws {
        #expect(try DocumentFile.text(from: Data(file.utf8)) == buffer)
    }

    @Test(arguments: [
        ("a", "a\n"),
        ("a\nb", "a\nb\n"),
        ("a\r\nb\r", "a\nb\n"),
        ("\u{FEFF}a", "\u{FEFF}a\n"),
        (" ", " \n"),
        // One grapheme, so a grapheme prefix test does not see the BOM.
        ("\u{FEFF}\u{301}", "\u{FEFF}\u{301}\n")
    ])
    func `a text with no final newline gets one in the buffer`(file: String, buffer: String) throws {
        #expect(try DocumentFile.text(from: Data(file.utf8)) == buffer)
    }

    @Test(arguments: ["", "\u{FEFF}"])
    func `an empty file opens and stays empty`(file: String) throws {
        #expect(try DocumentFile.text(from: Data(file.utf8)) == file)
    }

    @Test
    func `a leading BOM stays in the buffer`() throws {
        #expect(try DocumentFile.text(from: Data([0xEF, 0xBB, 0xBF, 0x23, 0x0D, 0x0A])) == "\u{FEFF}#\n")
    }

    @Test(arguments: ["a\nb", "a\r\nb\rc", "\u{FEFF}x\r", "a\n"])
    func `the saved bytes end with a newline and contain no CR`(edited: String) {
        let saved = DocumentFile.data(for: edited)
        #expect(saved.last == UInt8(ascii: "\n"))
        #expect(!saved.contains(UInt8(ascii: "\r")))
    }

    @Test
    func `the saved bytes keep the BOM and the text`() {
        #expect(DocumentFile.data(for: "\u{FEFF}a\r\nb") == Data([0xEF, 0xBB, 0xBF, 0x61, 0x0A, 0x62, 0x0A]))
    }

    @Test
    func `an empty text saves as no bytes`() {
        #expect(DocumentFile.data(for: "").isEmpty)
    }

    @Test
    func `an edit marks the document dirty and leaves the save to autosave`() {
        #expect(DocumentFile.saveAction(for: Self.change(.edit)) == .autosave)
    }

    @Test
    func `a checkbox change saves immediately`() {
        #expect(DocumentFile.saveAction(for: Self.change(.checkbox)) == .saveNow)
    }

    @Test(arguments: [TextChange.Reason.undo, .redo])
    func `undo or redo of a checkbox change saves immediately`(reason: TextChange.Reason) {
        #expect(DocumentFile.saveAction(for: Self.change(reason, group: .checkbox)) == .saveNow)
    }

    @Test(arguments: [TextChange.Reason.undo, .redo])
    func `undo or redo of an edit leaves the save to autosave`(reason: TextChange.Reason) {
        #expect(DocumentFile.saveAction(for: Self.change(reason, group: .edit)) == .autosave)
    }

    @Test
    func `a reload leaves the document clean`() {
        #expect(DocumentFile.saveAction(for: Self.change(.reload)) == .stayClean)
    }

    static func change(_ reason: TextChange.Reason, group: TextChange.Reason? = nil) -> TextChange {
        TextChange(reason: reason, groupReason: group ?? reason, range: NSRange(), replacement: "", text: "")
    }
}
