import Foundation
@testable import MarkdownCore
import Testing

/// Design › iPhone home screen (log 002), Windows and chrome (log 001): the
/// open and recent files, and the name of a new file.
struct FileListsTests {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    static func file(_ name: String, in folder: String = "Notes") -> URL {
        URL(filePath: "/Users/me/\(folder)/\(name)")
    }

    @Test
    func `opening moves a file from Recent to the end of Open, once`() {
        var lists = FileLists()
        lists.closed(Self.file("a.md"), at: start)

        lists.opened(Self.file("a.md"), at: start + 60)
        lists.opened(Self.file("b.md"), at: start + 120)
        lists.opened(Self.file("a.md"), at: start + 180)

        #expect(lists.open.map(\.url) == [Self.file("a.md"), Self.file("b.md")])
        #expect(lists.open.map(\.lastOpened) == [start + 180, start + 120])
        #expect(lists.recent.isEmpty)
    }

    @Test
    func `closing moves a file to the top of Recent`() {
        var lists = FileLists()
        lists.opened(Self.file("a.md"), at: start)
        lists.opened(Self.file("b.md"), at: start + 60)

        lists.closed(Self.file("a.md"), at: start + 120)
        lists.closed(Self.file("b.md"), at: start + 180)

        #expect(lists.open.isEmpty)
        #expect(lists.recent.map(\.url) == [Self.file("b.md"), Self.file("a.md")])
        #expect(lists.recent.map(\.lastOpened) == [start + 60, start])
    }

    @Test
    func `the Recent list keeps the 20 newest files`() {
        var lists = FileLists()
        for index in 0 ..< 21 {
            lists.closed(Self.file("\(index).md"), at: start + Double(index))
        }

        #expect(lists.recent.count == 20)
        #expect(lists.recent.first?.url == Self.file("20.md"))
        #expect(lists.recent.last?.url == Self.file("1.md"))
    }

    @Test
    func `removing a Recent file and closing a file leave the other list alone`() {
        var lists = FileLists()
        lists.opened(Self.file("a.md"), at: start)
        lists.closed(Self.file("b.md"), at: start)

        lists.removeRecent(Self.file("b.md"))
        lists.removeRecent(Self.file("a.md"))

        #expect(lists.open.map(\.url) == [Self.file("a.md")])
        #expect(lists.recent.isEmpty)
    }

    @Test
    func `a renamed open file keeps its place in Open`() {
        var lists = FileLists()
        lists.opened(Self.file("a.md"), at: start)
        lists.opened(Self.file("b.md"), at: start + 60)

        lists.replace(Self.file("a.md"), with: Self.file("c.md"))

        #expect(lists.open.map(\.url) == [Self.file("c.md"), Self.file("b.md")])
        #expect(lists.open.first?.lastOpened == start)
    }

    @Test
    func `a found file keeps its place in Recent`() {
        var lists = FileLists()
        lists.closed(Self.file("a.md"), at: start)
        lists.closed(Self.file("b.md"), at: start + 60)

        lists.replace(Self.file("a.md"), with: Self.file("a.md", in: "Moved"))

        #expect(lists.recent.map(\.url) == [Self.file("b.md"), Self.file("a.md", in: "Moved")])
        #expect(lists.recent.last?.lastOpened == start)
    }

    @Test(arguments: [
        ("", ["a.md", "Trip.md"], ["b.md"]),
        ("TRIP", ["Trip.md"], []),
        ("b", [], ["b.md"]),
        ("  trip ", ["Trip.md"], []),
        ("zzz", [], [])
    ])
    func `search filters both sections by file name, ignoring case and spaces`(
        query: String, open: [String], recent: [String]
    ) {
        var lists = FileLists()
        lists.opened(Self.file("a.md"), at: start)
        lists.opened(Self.file("Trip.md", in: "b"), at: start)
        lists.closed(Self.file("b.md"), at: start)

        let found = lists.matching(query)

        #expect(found.open.map(\.url.lastPathComponent) == open)
        #expect(found.recent.map(\.url.lastPathComponent) == recent)
    }

    @Test(arguments: [
        ([String](), "Untitled.md"),
        (["Untitled.md"], "Untitled 2.md"),
        (["untitled.MD", "Untitled 2.md"], "Untitled 3.md"),
        (["Untitled 2.md"], "Untitled.md")
    ])
    func `a new file is Untitled, then Untitled 2, ignoring case`(taken: [String], name: String) {
        #expect(DocumentFile.untitledName(taken: taken) == name)
    }

    @Test(arguments: [
        ("Trip.md", [], "Trip copy.md"),
        ("Trip.txt", ["trip COPY.txt"], "Trip copy 2.txt"),
        ("notes", ["notes copy"], "notes copy 2")
    ])
    func `a duplicate is name copy, then name copy 2, with the file's extension`(
        name: String, taken: [String], copy: String
    ) {
        #expect(DocumentFile.copyName(of: name, taken: taken) == copy)
    }
}
