import Foundation
import MarkdownCore

/// The folder sidebar's files (screens §3.5; log 004 Round 6): the accepted
/// files and the subfolders, New File, Rename, and Move to Trash.
enum FolderFiles {
    struct Entry: Equatable {
        let url: URL
        let isFolder: Bool

        var name: String {
            url.lastPathComponent
        }
    }

    enum RenameError: Error, Equatable {
        case nameTaken(String)
        case invalid
    }

    /// Hidden files and other types are left out; a folder it cannot read is empty.
    static func entries(in folder: URL) -> [Entry] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        )) ?? []
        return urls.compactMap { url in
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            return isFolder || DocumentFile.accepts(url) ? Entry(url: url, isFolder: isFolder) : nil
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// An empty `Untitled.md`, then `Untitled 2.md`, … in the folder.
    static func newFile(in folder: URL) throws -> URL {
        let taken = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        let url = folder.appending(path: DocumentFile.untitledName(taken: taken))
        try Data().write(to: url, options: .withoutOverwriting)
        return url
    }

    /// The new name in the same folder. A name another file has, ignoring case, is refused.
    /// The move is coordinated, so an open document follows it.
    static func rename(_ url: URL, to name: String) throws -> URL {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !name.contains("/") else { throw RenameError.invalid }
        let folder = url.deletingLastPathComponent()
        let renamed = folder.appending(path: name)
        let taken = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        // A change of case alone renames the same file.
        if taken.contains(where: { $0.lowercased() == name.lowercased() && $0 != url.lastPathComponent }) {
            throw RenameError.nameTaken(name)
        }
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var moveError: (any Error)?
        coordinator.coordinate(
            writingItemAt: url, options: .forMoving, writingItemAt: renamed, options: .forReplacing,
            error: &coordinationError
        ) { from, to in
            do {
                coordinator.item(at: from, willMoveTo: to)
                try FileManager.default.moveItem(at: from, to: to)
                coordinator.item(at: from, didMoveTo: to)
            } catch {
                moveError = error
            }
        }
        if let error = coordinationError ?? moveError {
            throw error
        }
        return renamed
    }

    /// Never a permanent delete; the result is where the file is in the Trash,
    /// for Undo. With `folder`, the file goes there instead: iOS has no Trash.
    static func trash(_ url: URL, into folder: URL? = nil) throws -> URL {
        if let folder {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let taken = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            let trashed = folder.appending(path: DocumentFile.freeName(url.lastPathComponent, taken: taken))
            try FileManager.default.moveItem(at: url, to: trashed)
            return trashed
        }
        var trashed: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashed)
        // trashItem names the new place whenever it succeeds.
        return trashed! as URL // swiftlint:disable:this force_unwrapping
    }

    /// Undo Move to Trash.
    static func restore(_ trashed: URL, to url: URL) throws {
        try FileManager.default.moveItem(at: trashed, to: url)
    }
}
