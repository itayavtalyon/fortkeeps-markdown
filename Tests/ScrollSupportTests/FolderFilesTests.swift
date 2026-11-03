import Foundation
@testable import ScrollSupport
import Testing

/// The folder sidebar's files (screens §3.5; log 004 Round 6).
struct FolderFilesTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "FolderFiles-\(UUID().uuidString)")

    func given(_ names: [String]) throws -> URL {
        try FileManager.default.createDirectory(at: folder.appending(path: "Sub"), withIntermediateDirectories: true)
        for name in names {
            try Data("x\n".utf8).write(to: folder.appending(path: name))
        }
        return folder
    }

    @Test
    func `the sidebar lists the accepted files and the subfolders by name, and nothing else`() throws {
        let folder = try given(["b.md", "A.markdown", "notes.txt", "photo.png", ".hidden.md", "c.MKD"])

        let entries = FolderFiles.entries(in: folder)

        #expect(entries.map(\.name) == ["A.markdown", "b.md", "c.MKD", "notes.txt", "Sub"])
        #expect(entries.map(\.isFolder) == [false, false, false, false, true])
        #expect(FolderFiles.entries(in: folder.appending(path: "missing")).isEmpty)
    }

    @Test
    func `a new file is Untitled.md, then Untitled 2.md`() throws {
        let folder = try given([])

        let first = try FolderFiles.newFile(in: folder)
        let second = try FolderFiles.newFile(in: folder)

        #expect(first.lastPathComponent == "Untitled.md")
        #expect(second.lastPathComponent == "Untitled 2.md")
        #expect(try Data(contentsOf: second).isEmpty)
    }

    @Test
    func `a rename keeps the folder and refuses a name that is taken`() throws {
        let folder = try given(["a.md", "b.md"])

        let renamed = try FolderFiles.rename(folder.appending(path: "a.md"), to: "c.md")

        #expect(renamed == folder.appending(path: "c.md"))
        #expect(FileManager.default.fileExists(atPath: renamed.path(percentEncoded: false)))
        #expect(throws: FolderFiles.RenameError.nameTaken("B.md")) {
            try FolderFiles.rename(renamed, to: "B.md")
        }
        #expect(throws: FolderFiles.RenameError.invalid) {
            try FolderFiles.rename(renamed, to: " ")
        }
        #expect(throws: FolderFiles.RenameError.invalid) {
            try FolderFiles.rename(renamed, to: "x/y.md")
        }
        #expect(try FolderFiles.rename(renamed, to: "c.md") == renamed)
        // A change of case alone is the same file, not a taken name.
        #expect(try FolderFiles.rename(renamed, to: "C.md") == folder.appending(path: "C.md"))
        #expect(throws: (any Error).self) {
            try FolderFiles.rename(folder.appending(path: "gone.md"), to: "d.md")
        }
    }

    #if os(macOS)
        @Test
        func `moving to the Trash moves the file there, and Undo restores it`() throws {
            let folder = try given(["a.md"])
            let file = folder.appending(path: "a.md")

            let trashed = try FolderFiles.trash(file)

            #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
            #expect(trashed.pathComponents.contains(".Trash"))
            try FolderFiles.restore(trashed, to: file)
            #expect(try Data(contentsOf: file) == Data("x\n".utf8))
        }
    #endif

    /// iOS has no system Trash: the app's own Trash folder, under a free name.
    @Test
    func `moving into the app's Trash folder keeps both files of one name, and Undo restores them`() throws {
        let folder = try given(["a.md"])
        let file = folder.appending(path: "a.md")
        let trash = folder.appending(path: "App/Trash")

        let first = try FolderFiles.trash(file, into: trash)
        try Data("y\n".utf8).write(to: file)
        let second = try FolderFiles.trash(file, into: trash)

        #expect([first, second].map(\.lastPathComponent) == ["a.md", "a 2.md"])
        #expect(first.deletingLastPathComponent().lastPathComponent == "Trash")
        try FolderFiles.restore(second, to: file)
        #expect(try Data(contentsOf: file) == Data("y\n".utf8))
    }

    @MainActor
    @Test
    func `an Undo that cannot put the file back beeps, opens nothing, and leaves no Redo`() throws {
        let url = try given(["a.md"]).appending(path: "a.md")
        var opened: [URL] = []
        var beeps = 0
        FileTrash.trash(
            url, into: folder.appending(path: "Trash"), close: { _ in {} },
            openFile: { opened.append($0) }, beep: { beeps += 1 }
        )
        // Another file takes the name before the Undo.
        try Data("new\n".utf8).write(to: url)

        FileTrash.undoManager.undo()

        #expect(beeps == 1)
        #expect(opened.isEmpty)
        #expect(try String(contentsOf: url, encoding: .utf8) == "new\n")
        #expect(!FileTrash.undoManager.canRedo)
        #expect(FileManager.default
            .fileExists(atPath: folder.appending(path: "Trash/a.md").path(percentEncoded: false)))
    }
}
